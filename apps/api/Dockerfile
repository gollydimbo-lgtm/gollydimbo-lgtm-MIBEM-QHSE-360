FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --fetch-retries=8 --fetch-retry-mintimeout=20000 --fetch-retry-maxtimeout=120000
COPY . .
RUN npx prisma generate && npm run build

FROM node:22-alpine
WORKDIR /app
COPY --from=build /app/package*.json ./
# On garde prisma (CLI) et tsx : ce sont eux qui exécutent "prisma migrate
# deploy" au démarrage du conteneur et "prisma db seed" via
# `docker compose exec api npx prisma db seed`. Sans eux, npx devrait les
# retélécharger à chaque appel — lent, et impossible sans accès au
# registre npm depuis le conteneur en production.
RUN npm install --fetch-retries=8 --fetch-retry-mintimeout=20000 --fetch-retry-maxtimeout=120000
ENV NODE_ENV=production
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build /app/node_modules/@prisma ./node_modules/@prisma
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/test ./test
EXPOSE 3000
CMD ["sh","-c","npx prisma migrate deploy && node dist/main.js"]
