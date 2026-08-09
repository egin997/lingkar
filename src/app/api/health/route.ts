export const dynamic = "force-dynamic";

export function GET() {
  return Response.json(
    {
      status: "ok",
      service: "lingkar-web",
      phase: "foundation",
    },
    {
      headers: {
        "Cache-Control": "no-store",
      },
    },
  );
}
