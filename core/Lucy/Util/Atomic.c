/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define C_LUCY_ATOMIC
#define LUCY_USE_SHORT_NAMES
#include "Lucy/Util/Atomic.h"

/********************************** Windows ********************************/
#ifdef CHY_HAS_WINDOWS_H
#include <windows.h>

chy_bool_t
lucy_Atomic_wrapped_cas_ptr(void *volatile *target, void *old_value,
                            void *new_value) {
    return InterlockedCompareExchangePointer(target, new_value, old_value)
           == old_value;
}

/************************** Fall back to ptheads ***************************/
#elif defined(CHY_HAS_PTHREAD_H)

#include <pthread.h>
pthread_mutex_t lucy_Atomic_mutex = PTHREAD_MUTEX_INITIALIZER;

#endif


