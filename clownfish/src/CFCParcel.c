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

#include <ctype.h>
#include <string.h>

#ifndef true
  #define true 1
  #define false 0
#endif

#define CFC_NEED_BASE_STRUCT_DEF
#include "CFCBase.h"
#include "CFCParcel.h"
#include "CFCUtil.h"

struct CFCParcel {
    CFCBase base;
    char *name;
    char *cnick;
    char *prefix;
    char *Prefix;
    char *PREFIX;
};

#define MAX_PARCELS 100
static CFCParcel *registry[MAX_PARCELS + 1];
static int first_time = true;

CFCParcel*
CFCParcel_singleton(const char *name, const char *cnick) {
    // Set up registry.
    if (first_time) {
        size_t i;
        for (i = 1; i < MAX_PARCELS; i++) { registry[i] = NULL; }
        first_time = false;
    }

    // Return the default parcel for either a blank name or a NULL name.
    if (!name || !strlen(name)) {
        return CFCParcel_default_parcel();
    }

    // Return an existing singleton if the parcel has already been registered.
    size_t i;
    for (i = 1; registry[i] != NULL; i++) {
        CFCParcel *existing = registry[i];
        if (strcmp(existing->name, name) == 0) {
            if (cnick && strcmp(existing->cnick, cnick) != 0) {
                CFCUtil_die("cnick '%s' for parcel '%s' conflicts with '%s'",
                            cnick, name, existing->cnick);
            }
            return existing;
        }
    }
    if (i == MAX_PARCELS) {
        CFCUtil_die("Exceeded maximum number of parcels (%d)", MAX_PARCELS);
    }

    // Register new parcel.
    CFCParcel *singleton = CFCParcel_new(name, cnick);
    registry[i] = singleton;

    return singleton;
}

void
CFCParcel_reap_singletons(void) {
    if (registry[0]) {
        // default parcel.
        CFCBase_decref((CFCBase*)registry[0]);
    }
    int i;
    for (i = 1; registry[i] != NULL; i++) {
        CFCParcel *parcel = registry[i];
        CFCBase_decref((CFCBase*)parcel);
    }
}

static int
S_validate_name_or_cnick(const char *orig) {
    const char *ptr = orig;
    for (; *ptr != 0; ptr++) {
        if (!isalpha(*ptr)) { return false; }
    }
    return true;
}

const static CFCMeta CFCPARCEL_META = {
    "Clownfish::CFC::Parcel",
    sizeof(CFCParcel),
    (CFCBase_destroy_t)CFCParcel_destroy
};

CFCParcel*
CFCParcel_new(const char *name, const char *cnick) {
    CFCParcel *self = (CFCParcel*)CFCBase_allocate(&CFCPARCEL_META);
    return CFCParcel_init(self, name, cnick);
}

CFCParcel*
CFCParcel_init(CFCParcel *self, const char *name, const char *cnick) {
    // Validate name.
    if (!name || !S_validate_name_or_cnick(name)) {
        CFCUtil_die("Invalid name: '%s'", name ? name : "[NULL]");
    }
    self->name = CFCUtil_strdup(name);

    // Validate or derive cnick.
    if (cnick) {
        if (!S_validate_name_or_cnick(cnick)) {
            CFCUtil_die("Invalid cnick: '%s'", cnick);
        }
        self->cnick = CFCUtil_strdup(cnick);
    }
    else {
        // Default cnick to name.
        self->cnick = CFCUtil_strdup(name);
    }

    // Derive prefix, Prefix, PREFIX.
    size_t cnick_len  = strlen(self->cnick);
    size_t prefix_len = cnick_len ? cnick_len + 1 : 0;
    size_t amount     = prefix_len + 1;
    self->prefix = (char*)MALLOCATE(amount);
    self->Prefix = (char*)MALLOCATE(amount);
    self->PREFIX = (char*)MALLOCATE(amount);
    memcpy(self->Prefix, self->cnick, cnick_len);
    if (cnick_len) {
        self->Prefix[cnick_len]  = '_';
        self->Prefix[cnick_len + 1]  = '\0';
    }
    else {
        self->Prefix[cnick_len] = '\0';
    }
    size_t i;
    for (i = 0; i < amount; i++) {
        self->prefix[i] = tolower(self->Prefix[i]);
        self->PREFIX[i] = toupper(self->Prefix[i]);
    }
    self->prefix[prefix_len] = '\0';
    self->Prefix[prefix_len] = '\0';
    self->PREFIX[prefix_len] = '\0';

    return self;
}

void
CFCParcel_destroy(CFCParcel *self) {
    FREEMEM(self->name);
    FREEMEM(self->cnick);
    FREEMEM(self->prefix);
    FREEMEM(self->Prefix);
    FREEMEM(self->PREFIX);
    CFCBase_destroy((CFCBase*)self);
}

static CFCParcel *default_parcel = NULL;

CFCParcel*
CFCParcel_default_parcel(void) {
    if (default_parcel == NULL) {
        default_parcel = CFCParcel_new("DEFAULT", "");
        registry[0] = default_parcel;
    }
    return default_parcel;
}

CFCParcel*
CFCParcel_clownfish_parcel(void) {
    return CFCParcel_singleton("Lucy", "Lucy");
}

int
CFCParcel_equals(CFCParcel *self, CFCParcel *other) {
    if (strcmp(self->name, other->name)) { return false; }
    if (strcmp(self->cnick, other->cnick)) { return false; }
    return true;
}

const char*
CFCParcel_get_name(CFCParcel *self) {
    return self->name;
}

const char*
CFCParcel_get_cnick(CFCParcel *self) {
    return self->cnick;
}

const char*
CFCParcel_get_prefix(CFCParcel *self) {
    return self->prefix;
}

const char*
CFCParcel_get_Prefix(CFCParcel *self) {
    return self->Prefix;
}

const char*
CFCParcel_get_PREFIX(CFCParcel *self) {
    return self->PREFIX;
}

