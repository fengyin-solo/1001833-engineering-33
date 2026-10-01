FROM node:20-alpine
WORKDIR /srv/web
# package-lock.json 是唯一版本来源，安装只走 npm ci
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
