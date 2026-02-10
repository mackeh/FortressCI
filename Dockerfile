FROM node:14-alpine
# Using an older image to intentionally trigger vulnerability findings
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "app.js"]
