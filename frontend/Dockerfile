# frontend/Dockerfile
FROM node:24-alpine

WORKDIR /app

# Install dependencies first (caching layer)
COPY package.json package-lock.json ./
RUN npm install

# Copy the rest of the code
COPY . .

# Expose the port Next.js runs on
EXPOSE 3000

# Start in development mode
CMD ["npm", "run", "dev"]