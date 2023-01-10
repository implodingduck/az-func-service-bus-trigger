const { delay, ServiceBusClient } = require("@azure/service-bus");
const { DefaultAzureCredential } = require("@azure/identity");

const fullyQualifiedNamespace = process.env.SERVICE_BUS_NAMESPACE__fullyQualifiedNamespace;
const credential = new DefaultAzureCredential();
const topicName = process.env.TOPIC_NAME;

module.exports = async function (context, myTimer) {
    var timeStamp = new Date().toISOString();
    
    if (myTimer.isPastDue)
    {
        context.log('JavaScript is running late!');
    }
    context.log('JavaScript timer trigger function ran!', timeStamp);   
    const sbClient = new ServiceBusClient(fullyQualifiedNamespace, credential);

    const receiver = sbClient.createReceiver(topicName, "subfuncservicebustopic");

    const myMessageHandler = async (messageReceived) => {
		context.log(`Received message: ${messageReceived.body}`);
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

	await receiver.close();	
	await sbClient.close();

};