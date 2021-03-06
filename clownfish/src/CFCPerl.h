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

#ifndef H_CFCPERL
#define H_CFCPERL

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CFCPerl CFCPerl;
struct CFCParcel;
struct CFCHierarchy;

CFCPerl*
CFCPerl_new(struct CFCParcel *parcel, struct CFCHierarchy *hierarchy,
            const char *lib_dir, const char *boot_class, const char *header,
            const char *footer);

CFCPerl*
CFCPerl_init(CFCPerl *self, struct CFCParcel *parcel,
             struct CFCHierarchy *hierarchy, const char *lib_dir,
             const char *boot_class, const char *header, const char *footer);

void
CFCPerl_destroy(CFCPerl *self);

/** Auto-generate POD for all class bindings where pod specs were created.
 * See whether a .pod file exists and is up-to-date; if not, write it out.
 * 
 * @return an array of filepaths where POD was written out.
 */
char**
CFCPerl_write_pod(CFCPerl *self);

void
CFCPerl_write_boot(CFCPerl *self);

void
CFCPerl_write_bindings(CFCPerl *self);

void
CFCPerl_write_xs_typemap(CFCPerl *self);

#ifdef __cplusplus
}
#endif

#endif /* H_CFCPERL */

