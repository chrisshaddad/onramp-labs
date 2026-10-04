FROM node:24-slim
WORKDIR /app
COPY package*.json ./
# Downloads everything at build time, so the demo needs no network.
# @confluentinc/kafka-javascript fetches a prebuilt librdkafka binding for linux-glibc-x64 here.
RUN npm ci --omit=dev && npm cache clean --force
COPY . .
RUN chmod +x bin/demo && ln -s /app/bin/demo /usr/local/bin/demo
USER node
WORKDIR /lab
CMD ["sleep", "infinity"]
