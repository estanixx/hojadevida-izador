'use server';

import { revalidatePath } from 'next/cache';

export async function createResume(formData: FormData) {
  const content = formData.get('resumeContent');

  // Hardcoded for now (until we add Cognito)
  const userId = 'simulated-user-1';

  console.log('Server Action: Sending to Backend...', process.env.BACKEND_URL);

  try {
    const res = await fetch(`${process.env.BACKEND_URL}/resume`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        userId: userId,
        data: content,
      }),
      // Don't cache this request (dynamic data)
      cache: 'no-store',
    });

    if (!res.ok) {
      const errorText = await res.text();
      console.error('Backend Error:', errorText);
      return { message: `Error: ${res.status} ${res.statusText}` };
    }

    const data = await res.json();
    console.log('Success:', data);

    // Refresh the UI if we were listing resumes
    revalidatePath('/');

    return { message: 'Success! Resume Saved.' };
  } catch (e: any) {
    console.error('Network Error:', e);
    return { message: 'Failed to connect to backend.' };
  }
}

export async function getPresignedUrl(filename: string) {
  console.log('Server Action: Requesting Upload URL for', filename);

  const { BACKEND_URL } = process.env;

  try {
    const res = await fetch(`${BACKEND_URL}/upload-url?filename=${filename}`, {
      method: 'GET',
      cache: 'no-store',
    });
    const data = await res.json();

    // --- THE SMART FIX ---
    let finalUrl = data.uploadUrl;

    // Only apply the "Localhost Patch" if we are in development mode
    if (process.env.NODE_ENV === 'development') {
      const urlObj = new URL(finalUrl);
      urlObj.hostname = 'localhost';
      urlObj.port = '4566';
      urlObj.protocol = 'http:';
      finalUrl = urlObj.toString();
    }

    // In Production, 'finalUrl' remains exactly what AWS gave us (https://s3.amazonaws.com...)
    return { success: true, url: finalUrl };
  } catch (e: any) {
    return { success: false, error: e.message };
  }
}
