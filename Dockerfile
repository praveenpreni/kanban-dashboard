FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY index.html vite.config.ts tsconfig*.json eslint.config.js postcss.config.js tailwind.config.js ./
COPY src ./src
COPY public ./public
RUN npm run build

FROM nginx:stable-alpine AS runtime
RUN addgroup -S -g 10001 app && adduser -S -D -H -u 10001 -G app app
COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY --from=build --chown=10001:10001 /app/dist /usr/share/nginx/html
USER 10001:10001
EXPOSE 8081
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 CMD wget -q -O - http://127.0.0.1:8081/healthz | grep -qx healthy || exit 1
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
