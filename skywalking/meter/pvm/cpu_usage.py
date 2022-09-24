#
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
#

import threading
import psutil

from skywalking.meter.pvm.data_source import DataSource


class CPUUsageDataSource(DataSource):
    def __init__(self):
        self.cur_process = psutil.Process()

    def total_cpu_utilization_generator(self):
        while (True):
            yield psutil.cpu_percent()

    def process_cpu_utilization_generator(self):
        while (True):
            yield self.cur_process.cpu_percent()

    def thread_active_count_generator(self):
        while (True):
            yield threading.active_count()
