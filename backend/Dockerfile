FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY tsconfig.json ./
COPY prisma ./prisma
RUN npx prisma generate
COPY src ./src
COPY .env.example ./.env
RUN npm run build
EXPOSE 3000
CMD ["sh","-c","npx prisma migrate deploy && npx tsx prisma/seed.ts && node dist/main.js"]
