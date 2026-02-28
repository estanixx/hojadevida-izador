import { NextResponse } from 'next/server'
export async function GET(request: Request) {
  return NextResponse.json({ status: 'healthy', message: 'Service is running normally' }, { status: 200 })
}