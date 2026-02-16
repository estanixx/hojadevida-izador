'use client'

import { useState } from 'react';
import { getPresignedUrl } from '../app/actions'; // Import the new action

export default function ResumeUploader() {
  const [file, setFile] = useState<File | null>(null);
  const [status, setStatus] = useState("");

  const handleUpload = async () => {
    if (!file) return;
    setStatus("Requesting permission...");

    try {
      // 1. Ask Next.js Server for the URL (Bypassing API Gateway CORS)
      const response = await getPresignedUrl(file.name);

      if (!response.success || !response.url) {
        throw new Error(response.error || "Failed to get URL");
      }

      setStatus("Uploading to S3...");

      // 2. Upload directly to S3
      // Note: S3 still needs CORS, but we configured that in template.yaml
      const uploadRes = await fetch(response.url, {
        method: "PUT",
        headers: { 
            "Content-Type": "application/pdf"
        },
        body: file,
      });

      if (uploadRes.ok) {
        setStatus("Success! Resume uploaded.");
      } else {
        const errText = await uploadRes.text();
        console.error("S3 Upload Error:", errText);
        setStatus("Upload failed: " + uploadRes.statusText);
      }

    } catch (e: any) {
      console.error(e);
      setStatus("Error: " + e.message);
    }
  };

  return (
    <div className="p-4 bg-gray-800 rounded mt-4 border border-gray-700">
      <input 
        type="file" 
        accept="application/pdf"
        onChange={(e) => setFile(e.target.files?.[0] || null)}
        className="block w-full text-sm text-gray-400 mb-2 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
      />
      <button 
        onClick={handleUpload}
        disabled={!file}
        className="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white font-bold py-2 px-4 rounded transition-colors"
      >
        Upload PDF
      </button>
      <p className="mt-2 text-yellow-400 font-mono text-xs">{status}</p>
    </div>
  );
}