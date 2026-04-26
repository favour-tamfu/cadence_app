import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "jose";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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

    // ── Parse request body
    const { book_id, file_path, pdf_hash } = await req.json();

    // ── Check cache — if we've extracted this PDF before, return existing
    const { data: existing } = await supabase
      .from("extraction_jobs")
      .select("*")
      .eq("pdf_hash", pdf_hash)
      .eq("status", "done")
      .single();

    if (existing) {
      return new Response(
        JSON.stringify({ job_id: existing.id, status: "done", cached: true }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── Download PDF from Supabase Storage
    const { data: fileData, error: downloadError } = await supabase.storage
      .from("books")
      .download(file_path);

    if (downloadError || !fileData) {
      throw new Error(`Storage download failed: ${downloadError?.message}`);
    }

    // ── Step 1: Get Adobe access token
    const tokenRes = await fetch("https://pdf-services-ue1.adobe.io/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: Deno.env.get("ADOBE_CLIENT_ID")!,
        client_secret: Deno.env.get("ADOBE_CLIENT_SECRET")!,
      }),
    });

    if (!tokenRes.ok) {
      throw new Error(`Adobe auth failed: ${await tokenRes.text()}`);
    }

    const { access_token } = await tokenRes.json();
    const adobeHeaders = {
      "Authorization": `Bearer ${access_token}`,
      "x-api-key": Deno.env.get("ADOBE_CLIENT_ID")!,
    };

    // ── Step 2: Get upload presigned URL from Adobe
    const uploadUrlRes = await fetch("https://pdf-services-ue1.adobe.io/assets", {
      method: "POST",
      headers: { ...adobeHeaders, "Content-Type": "application/json" },
      body: JSON.stringify({ mediaType: "application/pdf" }),
    });

    if (!uploadUrlRes.ok) {
      throw new Error(`Adobe upload URL failed: ${await uploadUrlRes.text()}`);
    }

    const { uploadUri, assetID } = await uploadUrlRes.json();

    // ── Step 3: Upload PDF to Adobe
    const pdfBytes = await fileData.arrayBuffer();
    const uploadRes = await fetch(uploadUri, {
      method: "PUT",
      headers: { "Content-Type": "application/pdf" },
      body: pdfBytes,
    });

    if (!uploadRes.ok) {
      throw new Error(`Adobe PDF upload failed: ${uploadRes.status}`);
    }

    // ── Step 4: Start extraction job
    const extractRes = await fetch(
      "https://pdf-services-ue1.adobe.io/operation/extractpdf",
      {
        method: "POST",
        headers: { ...adobeHeaders, "Content-Type": "application/json" },
        body: JSON.stringify({
          assetID,
          elementsToExtract: ["text", "tables"],
          renditionsToExtract: ["tables", "figures"],
        }),
      },
    );

    if (!extractRes.ok) {
      throw new Error(`Adobe extract failed: ${await extractRes.text()}`);
    }

    const adobeJobUrl = extractRes.headers.get("location");
    if (!adobeJobUrl) throw new Error("No job URL from Adobe");

    // ── Step 5: Store job in Supabase
    const { data: job, error: insertError } = await supabase
      .from("extraction_jobs")
      .insert({
        book_id,
        user_id: userId,
        adobe_job_id: adobeJobUrl,
        status: "processing",
        pdf_hash,
      })
      .select()
      .single();

    if (insertError) throw insertError;

    return new Response(
      JSON.stringify({ job_id: job.id, status: "processing" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("extract-start error:", e);
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
