import ResumeUploader from "@/components/ResumeUploader";
import { createResume } from "./actions";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24 bg-gray-900 text-white">
      <h1 className="text-4xl font-bold mb-8 text-blue-400">Harvard Resume Builder</h1>
      
      <div className="z-10 max-w-5xl w-full items-center justify-between font-mono text-sm">
        <form action={createResume} className="bg-gray-800 p-8 rounded-lg shadow-lg">
          <label className="block mb-2 text-lg">Resume Content (JSON or Text):</label>
          <textarea 
            name="resumeContent" 
            className="w-full h-32 p-2 text-black rounded mb-4"
            defaultValue="I am a software engineer..."
          />
          
          <button 
            type="submit"
            className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
          >
            Save to Cloud
          </button>
        </form>

        <div className="z-10 max-w-5xl w-full mt-8">
        <h2 className="text-2xl font-bold mb-4 text-blue-400">Phase 2: File Upload</h2>
        <ResumeUploader />
      </div>
      </div>
    </main>
  );
}