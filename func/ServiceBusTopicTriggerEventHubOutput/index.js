module.exports = async function(context, mySbMsg) {
    context.log('JavaScript ServiceBus topic trigger function processed message', mySbMsg);
    const timeStamp = new Date().toISOString();
    context.bindings.outputEventHubMessage = "From ServiceBusTopicTriggerEventHubOutput: " + mySbMsg + "(" + timeStamp + ")";
    context.done();
};