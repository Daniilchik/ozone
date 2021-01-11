/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.hadoop.ozone.container.upgrade;

import org.apache.hadoop.ozone.container.common.statemachine.DatanodeStateMachine;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Upgrade Action for DataNode for the very first first Upgrade Version.
 */
public class DataNodeUpgradeActionFirstUpgradeVersion
    implements DataNodeUpgradeAction {

  public static final Logger LOG =
      LoggerFactory.getLogger(DataNodeUpgradeActionFirstUpgradeVersion.class);
  @Override
  public void executeAction(DatanodeStateMachine arg) throws Exception {
    LOG.info("Executing datanode upgrade action for the very First Upgrade " +
        "Version.");
  }
}
