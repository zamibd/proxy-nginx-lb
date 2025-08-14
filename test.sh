#!/bin/bash

# Ports to test
PORTS=(99 98 500 4500)
URL="proxy.imzami.com"
REQUESTS_PER_PORT=5   # প্রতি iteration এ প্রতি পোর্টের রিকোয়েস্ট সংখ্যা

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Initialize counters
declare -A COUNT_A
declare -A COUNT_B

for PORT in "${PORTS[@]}"; do
  COUNT_A[$PORT]=0
  COUNT_B[$PORT]=0
done

echo -e "${YELLOW}Starting Heavy Load Random LB Monitor for $URL...${NC}"
echo "Press Ctrl+C to stop."
echo "--------------------------------------"

while true; do
  clear
  DATE=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${YELLOW}[$DATE] Heavy Load Load Balancer Status${NC}"
  echo "--------------------------------------"
  
  for PORT in "${PORTS[@]}"; do
    for ((i=1; i<=REQUESTS_PER_PORT; i++)); do
      RESPONSE=$(curl -s -m 2 http://$URL:$PORT)
      
      if [[ $RESPONSE == *"a.imzami.com"* ]]; then
        ((COUNT_A[$PORT]++))
      elif [[ $RESPONSE == *"b.imzami.com"* ]]; then
        ((COUNT_B[$PORT]++))
      fi
    done
    
    # Graph bars
    A_BAR=$(printf "%0.s■" $(seq 1 ${COUNT_A[$PORT]}))
    B_BAR=$(printf "%0.s■" $(seq 1 ${COUNT_B[$PORT]}))
    
    echo -e "Port $PORT -> a: ${GREEN}$A_BAR${NC} (${COUNT_A[$PORT]}) | b: ${RED}$B_BAR${NC} (${COUNT_B[$PORT]})"
  done
  
  sleep 2
done
