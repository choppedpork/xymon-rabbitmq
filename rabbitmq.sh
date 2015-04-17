#!/bin/bash

USERNAME=guest
PASSWORD=guest

# server stats
SEVERSTATSFILE=$(mktemp)
curl -s $USERNAME:$PASSWORD@localhost:15672/api/nodes/rabbit@$(hostname)\?columns=partitions,uptime|python -mjson.tool > $SEVERSTATSFILE
UPTIME=$(grep uptime $SEVERSTATSFILE|awk '{print $2}')
PARTITIONS=$(grep partitions $SEVERSTATSFILE|awk '{print $2}'|sed "s/^\[\(.*\)\],$/\1/")
UPTIME_=$(( $UPTIME / 60000 ))


TEST="rabbitmq.uptime"
COLOR="green"

if (( $UPTIME_ < 60 )); then
	COLOR=YELLOW
fi
if (( $UPTIME_ < 30 )); then
	COLOR=RED
fi

MESSAGE="uptime: $UPTIME_"

$BB $BBDISP   "status $MACHINE.$TEST $COLOR `date`
uptime: $UPTIME_ m"

TEST="rabbitmq.partitions"
COLOR="green"
if [ "a$PARTITIONS" != "a" ]; then COLOR="red"; fi

$BB $BBDISP   "status $MACHINE.$TEST $COLOR `date`
partitions: $PARTITIONS"

# queue stats

QUEUESTATSFILE=$(mktemp)
curl -s $USERNAME:$PASSWORD@localhost:15672/api/queues/%2F\?columns=name|python -mjson.tool|grep name|cut -d'"' -f4|while read queue; do
	TEST="rabbitmq."$(echo $queue|sed 's/\./_/g')
	COLOR="green"
	curl -s $USERNAME:$PASSWORD@localhost:15672/api/queues/%2F/$queue\?columns=state,consumers,messages,messages_ready|python -mjson.tool > $QUEUESTATSFILE
	CONSUMERS=$(grep consumers $QUEUESTATSFILE|awk '{print $2}'|sed s/,//)
	MESSAGES=$(grep messages\" $QUEUESTATSFILE|awk '{print $2}'|sed s/,//)
	MESSAGES_Q=$(grep messages_ready $QUEUESTATSFILE|awk '{print $2}'|sed s/,//)
	STATE=$(grep state $QUEUESTATSFILE|cut -d'"' -f4)

	if [ "$STATE" != "running" ]; then COLOR="red"; fi
	
	if (( $MESSAGES > 100 )); then COLOR="yellow"; fi
	if (( $MESSAGES > 1000 )); then COLOR="red"; fi

	if (( $MESSAGES_Q > 100 )); then COLOR="yellow"; fi
	if (( $MESSAGES_Q > 1000 )); then COLOR="red"; fi

	# we only want to check for consumers on non-dlq queues
	echo $queue|grep dlq > /dev/null
	if (( $? != 0)); then
		if (( $CONSUMERS < 2 )); then COLOR="yellow"; fi
		if (( $CONSUMERS == 0 )); then COLOR="red"; fi
	# we also want to shout about any messages on the queue for dlq
	else
		if (( $MESSAGES_Q > 0 )); then COLOR="red"; fi
	fi

	$BB $BBDISP   "status $MACHINE.$TEST $COLOR `date`
queue: $queue
state: $STATE
consumers: $CONSUMERS
messages: $MESSAGES
messages queued: $MESSAGES_Q"
done

rm $SEVERSTATSFILE $QUEUESTATSFILE

