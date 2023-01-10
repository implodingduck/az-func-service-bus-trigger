# az-func-service-bus-trigger

Sample Azure Function that shows interactions between Azure Service Bus and Event Hub.

* HttpTrigger - Generates a message and sends it on the service bus
* ServiceBusTopicTriggerEventHubOutput - Uses the input/output function bindings for reading a service bus topic and sending it to event hub
* TimerTrigger - Uses the javascript SDK clients to interact with reading service bus topic and sending it to event hub
* EventHubTrigger - Basic trigger to read things from event hub