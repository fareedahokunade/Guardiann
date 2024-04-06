#!/bin/bash

# Define the package and activity names of your Flutter app
PACKAGE_NAME='com.example.guardian'
ACTIVITY_NAME='com.example.guardian.MainActivity'
# Define how many times you want to launch the app to measure the startup time
NUM_RUNS=20

# Initialize total time
totalTime=0

for ((i=1; i<=NUM_RUNS; i++))
do
    # Launch the app and capture the output
    output=$(adb shell am start -W -n "${PACKAGE_NAME}/${ACTIVITY_NAME}" | grep TotalTime)
    # Extract the startup time from the output
    time=$(echo $output | cut -d ' ' -f 2)
    echo $time
    totalTime=$((totalTime + time))

    # Optionally, kill the app to measure cold start time only
    adb shell am force-stop $PACKAGE_NAME
    # Wait a bit before the next run
    sleep 2
done

# Calculate the average startup time
averageTime=$((totalTime / NUM_RUNS))

echo "Average startup time over $NUM_RUNS runs: $averageTime milliseconds"
