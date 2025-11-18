const { Kafka } = require('kafkajs');

const kafkaBootstrap = process.env.KAFKA_BOOTSTRAP_SERVERS || '192.168.150.130:9092,192.168.150.131:9092,192.168.150.132:9092';
const clientId = process.env.KAFKA_CLIENT_ID || 'the-backend';

const kafka = new Kafka({
  clientId,
  brokers: kafkaBootstrap.split(',').map(b => b.trim()),
  // 强制使用 IP 地址，忽略 broker 返回的主机名
  retry: {
    retries: 5
  },
  connectionTimeout: 10000,
  requestTimeout: 30000
});

const producer = kafka.producer();
let connected = false;

async function connectProducer() {
  if (!connected) {
    await producer.connect();
    connected = true;
  }
}

async function sendRatingEvent(event) {
  try {
    await connectProducer();
    const topic = process.env.KAFKA_TOPIC_RATINGS || 'ratings';
    await producer.send({
      topic,
      messages: [
        { value: JSON.stringify(event) }
      ]
    });
  } catch (err) {
    console.error('[kafkaProducer] Failed to send event', err);
    throw err;
  }
}

async function disconnectProducer() {
  if (connected) {
    await producer.disconnect();
    connected = false;
  }
}

module.exports = {
  sendRatingEvent,
  connectProducer,
  disconnectProducer
};