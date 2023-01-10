const { delay, ServiceBusClient } = require("@azure/service-bus");
const { EventHubProducerClient } = require("@azure/event-hubs");
const { DefaultAzureCredential } = require("@azure/identity");

const fullyQualifiedNamespace = process.env.SERVICE_BUS_NAMESPACE__fullyQualifiedNamespace;
const topicName = process.env.TOPIC_NAME;

const ehFullyQualifiedNamespace = process.env.EVENT_HUB_NAMESPACE__fullyQualifiedNamespace;
const eventHubName = "funceventhub";

const credential = new DefaultAzureCredential();


module.exports = async function (context, myTimer) {
    var timeStamp = new Date().toISOString();
    
    if (myTimer.isPastDue)
    {
        context.log('JavaScript is running late!');
    }
    context.log('JavaScript timer trigger function ran!', timeStamp); 
    //Configure service bus and event hub clients  
    const sbClient = new ServiceBusClient(fullyQualifiedNamespace, credential);
    const producer = new EventHubProducerClient(ehFullyQualifiedNamespace, eventHubName, credential);
    context.log('Clients created');

    //service bus client to receive messages
    const receiver = sbClient.createReceiver(topicName, "subfuncservicebustopic");
    context.log('sb receiver created');
    
    try{
        //event hub client to produce messages
        const batch = await producer.createBatch();
        context.log('eh batch producer created');

        //message handler for incoming service bus events
        const myMessageHandler = async (messageReceived) => {
            context.log(`Received message: ${messageReceived.body}`);
            batch.tryAdd({ body: `From TimerTrigger: ${messageReceived.body} (${timeStamp})` });
        };

        //error handler for service bus
        const myErrorHandler = async (error) => {
            context.log(error);
        };

        //configure handlers to the service bus receiver
        receiver.subscribe({
            processMessage: myMessageHandler,
            processError: myErrorHandler
        });
        context.log("sb subscribe defined")

        context.log("waiting 5000ms...")
        // Waiting to get messages
        await delay(5000);

        context.log(`Batch count... ${batch.count}`)
        //if we added messages send them to event hub
        if (batch.count > 0){
            context.log("Sending Batch...");
            await producer.sendBatch(batch);
        }
    } catch(e){
        context.log(e);
    } finally{
        //close everything out
        await receiver.close();	
        await sbClient.close();
        await producer.close();
    }
   
};