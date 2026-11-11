import { NextResponse } from "next/server";

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const entered = body?.password?.toString() ?? "";
    const expected = process.env.BAILIFF_PASSWORD || "Admin@248";

    if (entered === expected) {
      return NextResponse.json({ success: true });
    }

    return NextResponse.json(
      { success: false, error: "Invalid password" },
      { status: 401 }
    );
  } catch {
    return NextResponse.json(
      { success: false, error: "Bad request" },
      { status: 400 }
    );
  }
}
