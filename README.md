# TLS tester

This repository contains a simple TCP server and a TCP client testing tool used
to debug and reproduce issues with closed TCP connection. Multiple Keep Alive 
requests, along some dummy data packets, are sent from the client to the server 
and the server replies with Keep Alive Respones. Occasionally, some TCP RST 
packets are reseting the connection. Those TCP RST are not issued from neither
the client nor the server. 

## Deploying the TCP server

To deploy the TCP server, first switch context to your AKS cluster where the 
server should run. Deploy the server and service:

    kubectl apply -f tls_server/kubernetes/tls-server-svc.yaml
    kubectl apply -f tls_server/kubernetes/tls-server-deployment.yaml

and make a note of the external LoadBalancer IP that's been assigned to the
tls-server-svc. 

## Deploying the TCP client

First switch context to the intended AKS cluster. Then update the
`TCP_SERVER_IP` environment variable in the [deployment
manifest](tls_client/kubernetes/tls-client-deployment.yaml) to match the
public IP given to the TCP server. Then you can deploy the TCP client
deployment and service:

    kubectl apply - tls_client/kubernetes/tls-client-deployment.yaml

The deployment will then create 5 pods and spawn `TCP_CLIENT_COUNT` * 5
clients.

## Logging
By default, both the server and client log informational messages and above. 

On the server side, informational logs are issued for each client attempt to 
connect and when a connection is closed while errors when a Keep Alive message 
is not received within the predefined time limit. 

On the client side, error logs are issued when the server is unavailable, when 
the Keep Alive Response is not received and when the server has terminated the 
connection.

### Server
To get the logs on the **server** side, switch to the appropriate context and run:

    kubectl logs -f tls-server-{pod-name} 

Output

    13:59:20.318 [info]  Starting TCP listener...
    13:59:28.962 [info]  New TCP connection attempt {40, 88, 16, 219}:31809
    13:59:28.962 [info]  New TCP connection attempt {52, 186, 35, 194}:10082
    13:59:28.963 [info]  New TCP connection attempt {52, 186, 35, 194}:6654

To get only the error:
    
    kubectl logs tls-server-974f46f7f-6xlhl | grep error    # display only errors

A sample output of the above command would look like

    13:59:39.953 [error] Keep alive request not received {52, 186, 32, 168}:40551, #Port<0.1276>
    13:59:40.098 [error] Keep alive request not received {52, 186, 36, 171}:14933, #Port<0.1658>
    13:59:40.718 [error] Keep alive request not received {52, 186, 35, 194}:6055, #Port<0.2974>


Modify the command to see that the server indeed closed the connection:

    kubectl logs tls-server-974f46f7f-6xlhl | grep -A 2 error

Output:

    13:59:39.953 [error] Keep alive request not received {52, 186, 32, 168}:40551, #Port<0.1276>
    13:59:39.953 [info]  Terminating TCP connection from {52, 186, 32, 168}:40551 :keep_alive_missing
    --
    13:59:40.098 [error] Keep alive request not received {52, 186, 36, 171}:14933, #Port<0.1658>
    13:59:40.098 [info]  Terminating TCP connection from {52, 186, 36, 171}:14933 :keep_alive_missing
    --
    13:59:40.718 [error] Keep alive request not received {52, 186, 35, 194}:6055, #Port<0.2974>
    13:59:40.718 [info]  Terminating TCP connection from {52, 186, 35, 194}:6055 :keep_alive_missing

### Client
To get the logs on the **client** side, switch to the appropriate context and run:

    kubectl logs -f tls-client-{pod-name} 

    example:
    kubectl logs -f tls-client-749699745d-2m4h4

Output: 

    13:59:07.854 [error] Client 3295: Server terminated TCP connection, #Port<0.106196>
    13:59:07.867 [error] Client 3368: Server terminated TCP connection, #Port<0.106194>
    13:59:07.873 [error] Client 1564: Server terminated TCP connection, #Port<0.106195>


