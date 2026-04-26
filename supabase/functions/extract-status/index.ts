import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "jose";
import { unzipSync } from "https://esm.sh/fflate@0.8.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Parse Adobe structuredData.json into our simplified schema
function parseAdobeJson(elements: any[]): any[] {
  const result: any[] = [];

  for (const el of elements) {
    const path = el.Path ?? "";
    const text = el.Text?.trim() ?? "";

    if (!text && el.filePaths === undefined) continue;

    if (path.includes("H1") || path.includes("Title")) {
      result.push({ type: "h1", text });
    } else if (path.includes("H2")) {
      result.push({ type: "h2", text });
    } else if (path.includes("H3")) {
      result.push({ type: "h3", text });
    } else if (path.includes("P") || path.includes("LBody")) {
      if (text.length > 0) result.push({ type: "p", text });
    } else if (path.includes("Lbl") || path.includes("LI")) {
      if (text.length > 0) result.push({ type: "li", text });
    } else if (el.filePaths && el.filePaths.length > 0) {
      result.push({
        type: "img",
        src: el.filePaths[0],
        caption: el.attributes?.Caption ?? "",
      });
    } else if (text.length > 10) {
      result.push({ type: "p", text });
    }
  }

  return result;
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const issuer = Deno.env.get("SB_JWT_ISSUER") ?? `${supabaseUrl}/auth/v1`;
const JWKS = jose.createRemoteJWKSet(
  new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`),
);

async function verifyToken(req: Request): Promise<string> {
  const authHeader = req.headers.get("authorization");
  if (!authHeader) throw new Error("Missing authorization header");
  const [scheme, token] = authHeader.split(" ");
  if (scheme !== "Bearer" || !token) throw new Error("Invalid authorization header");
  const { payload } = await jose.jwtVerify(token, JWKS, { issuer });
  if (!payload.sub) throw new Error("No user ID in token");
  return payload.sub;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // ── Verify JWT via JWKS (supports ES256 and HS256)
    let userId: string;
    try {
      userId = await verifyToken(req);
    } catch {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    const { job_id: jobId } = await req.json();
    if (!jobId) {
      return new Response(JSON.stringify({ error: "Missing job_id" }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    // ── Load job from Supabase (scoped to this user)
    const { data: job, error: jobError } = await supabase
      .from("extraction_jobs")
      .select("*")
      .eq("id", jobId)
      .eq("user_id", userId)
      .single();

    if (jobError || !job) {
      return new Response(JSON.stringify({ error: "Job not found" }), {
        status: 404,
        headers: corsHeaders,
      });
    }

    // ── Already done — return cached content
    if (job.status === "done") {
      return new Response(
        JSON.stringify({ status: "done", content: job.content_json }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (job.status === "failed") {
      return new Response(
        JSON.stringify({ status: "failed", error: "Extraction failed" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── Still processing — check Adobe
    const tokenRes = await fetch("https://pdf-services-ue1.adobe.io/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: Deno.env.get("ADOBE_CLIENT_ID")!,
        client_secret: Deno.env.get("ADOBE_CLIENT_SECRET")!,
      }),
    });

    const { access_token } = await tokenRes.json();
    const adobeHeaders = {
      "Authorization": `Bearer ${access_token}`,
      "x-api-key": Deno.env.get("ADOBE_CLIENT_ID")!,
    };

    // ── Poll Adobe job status
    const statusRes = await fetch(job.adobe_job_id, { headers: adobeHeaders });

    if (!statusRes.ok) {
      throw new Error(`Adobe status check failed: ${statusRes.status}`);
    }

    const adobeStatus = await statusRes.json();

    if (adobeStatus.status === "in progress") {
      return new Response(
        JSON.stringify({ status: "processing", progress: adobeStatus.percent ?? 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (adobeStatus.status === "failed") {
      await supabase
        .from("extraction_jobs")
        .update({ status: "failed" })
        .eq("id", jobId);

      return new Response(
        JSON.stringify({ status: "failed", error: "Adobe extraction failed" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (adobeStatus.status === "done") {
      const downloadUrl =
        adobeStatus.content?.downloadUri ?? adobeStatus.resource?.downloadUri;

      if (!downloadUrl) throw new Error("No download URL in Adobe response");

      const zipRes = await fetch(downloadUrl);
      if (!zipRes.ok) {
        const errText = await zipRes.text();
        throw new Error(`Adobe download failed (${zipRes.status}): ${errText.slice(0, 200)}`);
      }

      const rawBytes = await zipRes.arrayBuffer();
      const firstByte = new Uint8Array(rawBytes)[0];

      let structuredData: any;

      if (firstByte === 0x50) {
        // ZIP (magic bytes PK) — legacy Adobe response
        const files = unzipSync(new Uint8Array(rawBytes));
        const entry = files["structuredData.json"];
        if (!entry) throw new Error("structuredData.json not found in ZIP");
        structuredData = JSON.parse(new TextDecoder().decode(entry));
      } else if (firstByte === 0x7B) {
        // JSON directly — newer Adobe API response
        structuredData = JSON.parse(new TextDecoder().decode(rawBytes));
      } else {
        throw new Error(`Unexpected response format (first byte: 0x${firstByte.toString(16)})`);
      }

      if (!structuredData.elements) {
        throw new Error("No elements in structuredData");
      }

      const elements = parseAdobeJson(structuredData.elements);

      const content = {
        elements,
        meta: {
          charCount: elements
            .filter((e) => e.text)
            .reduce((sum, e) => sum + (e.text?.length ?? 0), 0),
          pageCount: structuredData.extended_metadata?.page_count ?? 0,
        },
      };

      await supabase
        .from("extraction_jobs")
        .update({ status: "done", content_json: content })
        .eq("id", jobId);

      return new Response(
        JSON.stringify({ status: "done", content }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ status: "processing", progress: 0 }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("extract-status error:", e);
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
