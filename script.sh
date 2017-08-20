#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Build your first network (BYFN - Fabcar example) end-to-end test"
echo
CHANNEL_NAME="$1"
: ${CHANNEL_NAME:="mychannel"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

echo "Channel name : "$CHANNEL_NAME

# verify the result of the end-to-end test
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
		echo
   		exit 1
	fi
}

setGlobals () {

	CORE_PEER_LOCALMSPID="Org1MSP"
	CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
	CORE_PEER_ADDRESS=peer0.org1.example.com:7051

	env | grep CORE
}

createChannel() {
	setGlobals 0 # call the function and pass the argument 0 to it

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx >&log.txt
	else
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed" # passes in 2 arguments to the function
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

updateAnchorPeers() {
  PEER=$1
  setGlobals $PEER

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	else
		peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep 2
		joinWithRetry $1
	else
		COUNTER=1
	fi
  verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	#for ch in 0 1 2 3; do
	for ch in 0; do # only want to join Peer 0
		setGlobals $ch
		joinWithRetry $ch
		echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep 2
		echo
	done
}

installFabcarChaincode () {
	PEER=$1
	setGlobals $PEER
	peer chaincode install -n fabcar -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/fabcar >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}

instantiateFabcarChaincode () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME -n fabcar -v 1.0 -c '{"Args":[""]}' -P "OR	('Org1MSP.member', 'Org2MSP.member')" >&log.txt
	else
		peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n fabcar -v 1.0 -c '{"Args":[""]}' -P "OR	('Org1MSP.member', 'Org2MSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

queryAllCars () {
  PEER=$1
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n fabcar -c '{"function":"queryAllCars","Args":[""]}' >&log.txt
  done
  echo
  cat log.txt
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
}

queryCar4 () {
  PEER=$1
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n fabcar -c '{"function":"queryCar","Args":["CAR4"]}' >&log.txt
  done
  echo
  cat log.txt
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
}

queryCar10 () {
  PEER=$1
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n fabcar -c '{"function":"queryCar","Args":["CAR10"]}' >&log.txt
  done
  echo
  cat log.txt
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
}


createCar10 () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n fabcar -c '{"function":"createCar","Args":["CAR10", "Chevy", "Volt", "Red", "Nick"]}' >&log.txt
	else
		peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n fabcar -c '{"function":"createCar","Args":["CAR10", "Chevy", "Volt", "Red", "Nick"]}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke initLedger transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

chaincodeInvoke () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	else
		peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

initialiseFabcarChaincode () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n fabcar -c '{"function":"initLedger","Args":[""]}' >&log.txt
	else
		peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n fabcar -c '{"function":"initLedger","Args":[""]}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke initLedger transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having Peer0 join the channel..."
joinChannel

## Set the anchor peers for org1 in the channel
echo "Updating anchor peers for org1..."
updateAnchorPeers 0

## Install chaincode on Org1/Peer0
echo "Installing Fabcar chaincode on org1/peer0..."
installFabcarChaincode 0

#Instantiate chaincode on Orge1/Peer0
echo "Instantiating Fabcar chaincode on org1/peer0..."
instantiateFabcarChaincode 0

echo "Sleeping 60 seconds to ensure the chaincode container is instantiated ..."
sleep 60

#Invoke on chaincode on Org1/Peer0
echo "Sending initialise Fabcar transaction on org1/peer0..."
initialiseFabcarChaincode 0

echo "Sleeping 30 seconds before querying ..."
sleep 30

#Query on chaincode on Org1/Peer0
echo "Querying all cars on org1/peer0..."
queryAllCars 0

# Query CAR4
echo "Querying CAR4 on org1/peer0..."
# My preference was to pass in arguments to a function but I don't know the BASH syntax to pass a string
# to a function and then reference it inside a quoted argument
# I tried passing queryCar 0 "CAR4" and then in function
# CAR=$1
# peer chaincode query -C $CHANNEL_NAME -n fabcar -c '{"function":"queryCar","Args":['$CAR']}' >&log.txt
# but it did not work
queryCar4 0

# Create CAR10
echo "Creating CAR10 on org1/peer0..."
# As with query I wanted to pass arguments to the function
# createCar 0 CAR10 Chevy Volt Red Nick
createCar10 0

# Query CAR10
echo "Querying CAR10 on org1/peer0..."
queryCar10 0


echo
echo "========= All GOOD, BYFN execution (Fabcar example) completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0
