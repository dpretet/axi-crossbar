Master interface

1. master 0 issue a request to ADDR=4 => SLV1
2. put in shape the channels, bufferize
3. decode the address and assert the request and the slav targeted

Interconnect

1. receive a request from master 0
2. target the slave and indicate the source master ID
3. enable the address channel until the handshake, 
   pass the source ID to the data channel (if write request)

Slave

1. grab the address channel, store the source id + request id
2. grab the data channel (if write request)
3. complete the transaction + pass the source ID, 
   release the outstanding request if reordering mode enabled

Interconnect

1. route the completion

Master 

1. route the completion
