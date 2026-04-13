# Methodology
- Deeply explore the architecture of the application  (create a brief README explaining its context and structure, an AI-powered app to create CVs) before continuing
- Determine the order to apply the changes
- Determine certain number of controlled steps and a way to test/validate each by you and me.
- Apply them one by one so we can test it and validate it (pushing it and deploying it) before moving forward.
- Follow best architectural patterns and desicions, tell me if im suggesting any bad practice.


# Changes: 
## Refactor 
- Refactor the cloudformation code in /infrastructure to be in terraform (reflect this changes in the deployment, now using terraform)
## Frontend
- Add a button to go back in the form wizard component in frontend to go to the former question and another to go back to the home page.
- Ask login to create cv.
- create another page in the navbar called CVs where a listing of the user CVs will be shown. Require login with cognito.
- Add another section with the social media of the user in the form wizard. Github and linkedin. This will be stored in a social attribute in the json. With an key-value, 
- Add a field for description of the desiredRole (now a json object with title and description)
## Backend
- Create a function to get all the cvs of the user that made the request (the function will require cognito so use that user for it)
- Create a function to create a cv using bedrock. This is the schema. optimize token usage.
- Prevent the ai to invent information, just include whats alligned with the job position and some other valuable skills
```
{

  "personalInfo": {
    "fullName": "",
    "email": "",
    "phone": "",
    "location": "",
    "desiredRole": {
      title, description
    }
  },
  socials: {github, linkedin}
  "experiences": [
    {
      "id": "c273213e-1c55-404a-baf0-6b79c85b8449",
      "enterpriseName": "",
      "fromDate": "",
      "toDate": "",
      "metrics": "",
      "achievements": ""
    }
  ],
  "skills": [],
  "languages": [
    {
      "id": "4e06bc73-3397-4d70-b489-17bf1a4cafa0",
      "language": "",
      "proficiencyLevel": ""
    }
  ],
  "additionalInformation": "",
  "summary": "",
  "education": [],
  "certifications": []
}
```
The CV should be a pdf properly formatted each section has its title in uppercase bold and then an horizontal line , ask bedrock to return a proper data structure with all the natural language text needed to do something like CVEXAMPLE.md


## Deployment
- Deploy the backend using serverless in the gh actions deploy.
- Pass the necessary information for the frontend to know the backend endpoints and the authorization endpoint for cognito.
- Tell me all the credentials needed to set the github repo.
