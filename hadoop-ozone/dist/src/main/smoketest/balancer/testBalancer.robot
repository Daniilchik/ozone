# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

*** Settings ***
Documentation       Smoketest ozone cluster startup
Library             OperatingSystem
Library             String
Library             Collections
Resource            ../commonlib.robot
Resource            ../ozone-lib/shell.robot

Test Timeout        20 minutes

*** Variables ***
${SECURITY_ENABLED}                 false
${HOST}                             datanode1
${VOLUME}                           volume1
${BUCKET}                           bucket1
${SIZE}                             104857600


** Keywords ***
Prepare For Tests
    Execute             dd if=/dev/urandom of=/tmp/100mb bs=1048576 count=100
    Run Keyword if      '${SECURITY_ENABLED}' == 'true'     Kinit test user    testuser    testuser.keytab
    Execute                 ozone sh volume create /${VOLUME}
    Execute                 ozone sh bucket create --replication ${REPLICATION} --type ${TYPE} /${VOLUME}/${BUCKET}


Datanode In Maintenance Mode
    ${result} =             Execute                         ozone admin datanode maintenance ${HOST}
                            Should Contain                  ${result}             Entering maintenance mode on datanode
    ${result} =             Execute                         ozone admin datanode list | grep "Operational State:*"
                            Wait Until Keyword Succeeds      30sec   5sec    Should contain   ${result}   ENTERING_MAINTENANCE
                            Wait Until Keyword Succeeds      3min    10sec   Related pipelines are closed
                            Sleep                   60000ms

Related pipelines are closed
    ${result} =         Execute          ozone admin datanode list | awk -v RS= '{$1=$1}1'|grep MAINT | sed -e 's/^.*pipelines: \\(.*\\)$/\\1/'
                        Should Contain Any   ${result}   CLOSED   No related pipelines or the node is not in Healthy state.

Datanode Recommission
    ${result} =             Execute                         ozone admin datanode recommission ${HOST}
                            Should Contain                  ${result}             Started recommissioning datanode
                            Wait Until Keyword Succeeds      1min    10sec    Datanode Recommission is Finished
                            Sleep                   300000ms

Datanode Recommission is Finished
    ${result} =             Execute                         ozone admin datanode list | grep "Operational State:*"
                            Should Not Contain   ${result}   ENTERING_MAINTENANCE

Run Container Balancer
    ${result} =             Execute                         ozone admin containerbalancer start -t 0.1 -d 100 -i 1
                            Should Contain                  ${result}             Container Balancer started successfully.

Wait Finish Of Balancing
    ${result} =             Execute                         ozone admin containerbalancer status -v --history
                            Should Contain                  ${result}             ContainerBalancer is Running.
                            Wait Until Keyword Succeeds      4min    10sec    ContainerBalancer is Not Running
                            Sleep                   60000ms

Verify Verbose Balancer Status
    [arguments]    ${output}

    Should Contain    ${output}    ContainerBalancer is Running.
    Should Contain    ${output}    Started at:
    Should Contain    ${output}    Container Balancer Configuration values:

Verify Balancer Iteration
    [arguments]    ${output}    ${number}    ${status}    ${containers}

    Should Contain    ${output}    Iteration number                                   ${number}
    Should Contain    ${output}    Iteration result                                   ${status}
    Should Contain    ${output}    Scheduled to move containers                       ${containers}

Run Balancer Status
    ${result} =      Execute                         ozone admin containerbalancer status -v
                     Should Contain                  ${result}             ContainerBalancer is Running.

Run Balancer Verbose Status
    ${result} =      Execute                         ozone admin containerbalancer status -v --history
                     Verify Verbose Balancer Status    ${result}
                     Verify Balancer Iteration    ${result}    1    IN_PROGRESS    3
                     Should Contain                  ${result}             Current iteration info:

Run Balancer Verbose History Status
    ${result} =    Execute                         ozone admin containerbalancer status -v --history
                   Verify Verbose Balancer Status          ${result}
                   Verify Balancer Iteration    ${result}    1    IN_PROGRESS    3
                   Should Contain                  ${result}             Iteration history list:

ContainerBalancer is Not Running
    ${result} =         Execute          ozone admin containerbalancer status
                        Should contain   ${result}   ContainerBalancer is Not Running.

Create Multiple Keys
    [arguments]             ${NUM_KEYS}
    ${file} =    Set Variable    /tmp/100mb
    FOR     ${INDEX}        IN RANGE                ${NUM_KEYS}
            ${fileName} =           Set Variable            file-${INDEX}.txt
            ${key} =    Set Variable    /${VOLUME}/${BUCKET}/${fileName}
            LOG             ${fileName}
            Create Key    ${key}    ${file}    --replication=${REPLICATION} --type=${TYPE}
            Key Should Match Local File    ${key}      ${file}
    END

Datanode Usageinfo
    [arguments]             ${uuid}
    ${result} =             Execute               ozone admin datanode usageinfo --uuid=${uuid}
                            Should Contain                  ${result}             Ozone Used

Get Uuid
    ${result} =             Execute          ozone admin datanode list | awk -v RS= '{$1=$1}1'| grep ${HOST} | sed -e 's/Datanode: //'|sed -e 's/ .*$//'
    [return]          ${result}

Close All Containers
    FOR     ${INDEX}    IN RANGE    15
        ${container} =      Execute          ozone admin container list --state OPEN | jq -r 'select(.replicationConfig.data == 3) | .containerID' | head -1
        EXIT FOR LOOP IF    "${container}" == "${EMPTY}"
                            ${message} =    Execute And Ignore Error    ozone admin container close "${container}"
                            Run Keyword If    '${message}' != '${EMPTY}'      Should Contain   ${message}   is in closing state
        ${output} =         Execute          ozone admin container info "${container}"
                            Should contain   ${output}   CLOS
    END
    Wait until keyword succeeds    4min    10sec    All container is closed
    Sleep                   300000ms
All container is closed
    ${output} =         Execute           ozone admin container list --state OPEN
                        Should Be Empty   ${output}

Get Datanode Ozone Used Bytes Info
    [arguments]             ${uuid}
    ${output} =    Execute    export DATANODES=$(ozone admin datanode list --json) && for datanode in $(echo "$\{DATANODES\}" | jq -r '.[].datanodeDetails.uuid'); do ozone admin datanode usageinfo --uuid=$\{datanode\} --json | jq '{(.[0].datanodeDetails.uuid) : .[0].ozoneUsed}'; done | jq -s add
    ${result} =    Execute    echo '${output}' | jq '. | to_entries | .[] | select(.key == "${uuid}") | .value'
    [return]          ${result}

** Test Cases ***
Verify Container Balancer for RATIS/EC containers
    Prepare For Tests

    Datanode In Maintenance Mode

    ${uuid} =                   Get Uuid
    Datanode Usageinfo          ${uuid}

    Create Multiple Keys          ${KEYS}

    Close All Containers

    ${datanodeOzoneUsedBytesInfo} =    Get Datanode Ozone Used Bytes Info          ${uuid}
    Should Be True    ${datanodeOzoneUsedBytesInfo} < ${SIZE}

    Datanode Recommission

    Run Container Balancer

    Run Balancer Status

    Run Balancer Verbose Status

    Run Balancer Verbose History Status

    Wait Finish Of Balancing

    ${datanodeOzoneUsedBytesInfoAfterContainerBalancing} =    Get Datanode Ozone Used Bytes Info          ${uuid}
    Should Not Be Equal As Integers     ${datanodeOzoneUsedBytesInfo}    ${datanodeOzoneUsedBytesInfoAfterContainerBalancing}
    #We need to ensure that after balancing, the amount of data recorded on each datanode falls within the following ranges:
    #{SIZE}*3 < used < {SIZE}*3.5 for RATIS containers, and {SIZE}*1.5 < used < {SIZE}*2.5 for EC containers.
    Should Be True    ${datanodeOzoneUsedBytesInfoAfterContainerBalancing} < ${SIZE} * ${UPPER_LIMIT}
    Should Be True    ${datanodeOzoneUsedBytesInfoAfterContainerBalancing} > ${SIZE} * ${LOWER_LIMIT}





