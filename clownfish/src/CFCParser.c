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
#include <stdio.h>
#include <stdlib.h>

#define CFC_NEED_BASE_STRUCT_DEF
#include "CFCBase.h"
#include "CFCParser.h"
#include "CFCUtil.h"

/* Routines generated by Lemon. */
void*
CFCParseHeaderAlloc(void * (*allocate)(size_t));
void
CFCParseHeader(void *header_parser, int token_type, CFCBase *value,
               CFCParserState *state);
void
CFCParseHeaderFree(void *header_parser, void(*freemem)(void*));
void
CFCParseHeaderTrace(FILE *trace, char *line_prefix);

struct CFCParser {
    CFCBase base;
    void *header_parser;
};

CFCParser*
CFCParser_new(void) {
    CFCParser *self = (CFCParser*)CFCBase_allocate(sizeof(CFCParser),
                                                   "Clownfish::Parser");
    return CFCParser_init(self);
}

CFCParser*
CFCParser_init(CFCParser *self) {
    self->header_parser = CFCParseHeaderAlloc(malloc);
    if (self->header_parser == NULL) {
        CFCUtil_die("Failed to allocate header parser");
    }
    return self;
}

void
CFCParser_destroy(CFCParser *self) {
    CFCParseHeaderFree(self->header_parser, free);
    CFCBase_destroy((CFCBase*)self);
}


