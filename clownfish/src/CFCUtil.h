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

#ifndef H_CFCUTIL
#define H_CFCUTIL

/** Create an inner Perl object with a refcount of 1.  For use in actual
 * Perl-space, it is necessary to wrap this inner object in an RV.
 */
void*
CFCUtil_make_perl_obj(void *ptr, const char *klass);

/** Throw an error if the supplied argument is NULL.
 */
void
CFCUtil_null_check(const void *arg, const char *name, const char *file, int line);
#define CFCUTIL_NULL_CHECK(arg) \
    CFCUtil_null_check(arg, #arg, __FILE__, __LINE__)

/** Portable, NULL-safe implementation of strdup().
 */
char*
CFCUtil_strdup(const char *string);

/** Portable, NULL-safe implementation of strndup().
 */
char*
CFCUtil_strndup(const char *string, size_t len);

/** Trim whitespace from the beginning and the end of a string.
 */
void
CFCUtil_trim_whitespace(char *text);

#endif /* H_CFCUTIL */

