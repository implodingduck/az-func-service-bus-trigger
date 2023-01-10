const { delay, ServiceBusClient } = require("@azure/service-bus");
const { EventHubProducerClient } = require("@azure/event-hubs");
const { DefaultAzureCredential } = require("@azure/identity");

const fullyQualifiedNamespace = process.env.SERVICE_BUS_NAMESPACE__fullyQualifiedNamespace;
const ehFullyQualifiedNamespace = process.env.EVENT_HUB_NAMESPACE__fullyQualifiedNamespace;
const credential = new DefaultAzureCredential();
const topicName = process.env.TOPIC_NAME;
const eventHubName = "funceventhub";

module.exports = async function (context, myTimer) {
    var timeStamp = new Date().toISOString();
    
    if (myTimer.isPastDue)
    {
        context.log('JavaScript is running late!');
    }
    context.log('JavaScript timer trigger function ran!', timeStamp);   
    const sbClient = new ServiceBusClient(fullyQualifiedNamespace, credential);
    const producer = new EventHubProducerClient(ehFullyQualifiedNamespace, eventHubName, credential);

    const receiver = sbClient.createReceiver(topicName, "subfuncservicebustopic");

    const batch = await producer.createBatch();
    const myMessageHandler = async (messageReceived) => {
		context.log(`Received message: ${messageReceived.body}`);
        batch.tryAdd({ body: messageReceived.body });
    };

    const myErrorHandler = async (error) => {
		context.log(error);
	};

    receiver.subscribe({
		processMessage: myMessageHandler,
		processError: myErrorHandler
	});

	// Waiting long enough before closing the sender to send messages
	await delay(5000);
    if (batch.count > 0){
        context.log('Sending Batch...');
        await producer.sendBatch(batch);
    }
    
	await receiver.close();	
	await sbClient.close();
    await producer.close();
};