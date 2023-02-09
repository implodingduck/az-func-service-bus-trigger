const { ServiceBusClient } = require("@azure/service-bus");
const { DefaultAzureCredential } = require("@azure/identity");

const fullyQualifiedNamespace = process.env.SERVICE_BUS_NAMESPACE__fullyQualifiedNamespace;
const credential = new DefaultAzureCredential();
const topicName = process.env.TOPIC_NAME;

module.exports = async function (context, req) {
    context.log('JavaScript HTTP trigger function processed a request.');

    const name = (req.query.name || (req.body && req.body.name));
    const responseMessage = name
        ? "Hello, " + name + ". This HTTP triggered function executed successfully."
        : "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.";

    const sbClient = new ServiceBusClient(fullyQualifiedNamespace, credential);
    const sender = sbClient.createSender(topicName);

    try {
        await sender.sendMessages([
            { body: responseMessage },
            { body: responseMessage.replace("Hello", "Hola") },
            { body: responseMessage.replace("Hello", "Bonjour") },
            { body: responseMessage.replace("Hello", "Hallo") }
        ]);
        
        await sender.close();
    }finally {
		await sbClient.close();
        context.res = {
            // status: 200, /* Defaults to 200 */
            body: responseMessage
        };
	}

}