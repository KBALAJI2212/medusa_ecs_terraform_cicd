FROM node:20-alpine

WORKDIR /app

COPY ./medusa-starter-default /app/

RUN npm install --omit=dev

RUN npm run build

WORKDIR /app/.medusa/server/

RUN npm install --omit=dev

CMD ["sh", "-c", "npm run predeploy && npm run start"]