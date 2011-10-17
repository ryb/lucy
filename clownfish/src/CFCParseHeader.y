%name CFCParseHeader

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

%token_type { CFCBase* }
%token_destructor { CFCBase_decref((CFCBase*)$$); }
%token_prefix CFC_TOKENTYPE_

%extra_argument { CFCParserState *state }

%include {
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
#include "CFC.h"
#ifndef true
  #define true 1
  #define false 0
#endif

static const char KW_INT8_T[]   = "int8_t";
static const char KW_INT16_T[]  = "int16_t";
static const char KW_INT32_T[]  = "int32_t";
static const char KW_INT64_T[]  = "int64_t";
static const char KW_UINT8_T[]  = "uint8_t";
static const char KW_UINT16_T[] = "uint16_t";
static const char KW_UINT32_T[] = "uint32_t";
static const char KW_UINT64_T[] = "uint64_t";
static const char KW_CHAR[]     = "char";
static const char KW_SHORT[]    = "short";
static const char KW_INT[]      = "int";
static const char KW_LONG[]     = "long";
static const char KW_SIZE_T[]   = "size_t";
static const char KW_BOOL_T[]   = "bool_t";
static const char KW_FLOAT[]    = "float";
static const char KW_DOUBLE[]   = "double";
}

%syntax_error {
    state->errors = true;
    FREEMEM(state->text);
    state->text = NULL;
    state->cap = 0;
}

%parse_accept {
    FREEMEM(state->text);
    state->text = NULL;
    state->cap = 0;
}

/* Temporary. */
result ::= type(A).                   { state->result = A; }
result ::= param_list(A).             { state->result = A; }
result ::= param_variable(A).         { state->result = A; }
result ::= docucomment(A).            { state->result = A; }
result ::= parcel_definition(A).      { state->result = A; }

parcel_definition(A) ::= PARCEL class_name(B) SEMICOLON.
{
    A = (CFCBase*)CFCParcel_singleton(B, NULL);
    CFCParser_set_parcel((CFCParcel*)A);
}

parcel_definition(A) ::= PARCEL class_name(B) cnick(C) SEMICOLON.
{
    A = (CFCBase*)CFCParcel_singleton(B, C);
    CFCParser_set_parcel((CFCParcel*)A);
}

type(A) ::= simple_type(B).            { A = B; }
type(A) ::= composite_type(B).         { A = B; }

composite_type(A) ::= simple_type(B) asterisk_postfix(C).
{
    int indirection = strlen(C);
    A = (CFCBase*)CFCType_new_composite(0, (CFCType*)B, indirection, NULL);
}

composite_type(A) ::= simple_type(B) array_postfix(C).
{
    A = (CFCBase*)CFCType_new_composite(0, (CFCType*)B, 0, C);
}

simple_type(A) ::= object_type(B).  { A = B; }
simple_type(A) ::= void_type(B).    { A = B; }
simple_type(A) ::= float_type(B).   { A = B; }
simple_type(A) ::= integer_type(B). { A = B; }
simple_type(A) ::= va_list_type(B). { A = B; }
simple_type(A) ::= arbitrary_type(B). { A = B; }

void_type(A) ::= CONST void_type_specifier.
{
    A = (CFCBase*)CFCType_new_void(true);
}

void_type(A) ::= void_type_specifier.
{
    A = (CFCBase*)CFCType_new_void(false);
}

%type float_type_specifier          {const char*}
%type integer_type_specifier        {const char*}
%type object_type_specifier         {char*}
%type type_qualifier                {int}
%type type_qualifier_list           {int}
%type scalar_constant               {char*}
%type integer_literal               {char*}
%type float_literal                 {char*}
%type hex_literal                   {char*}
%type string_literal                {char*}
%type asterisk_postfix              {char*}
%type array_postfix                 {char*}
%type array_postfix_elem            {char*}
%type declarator                    {char*}
%type class_name                    {char*}
%type cnick                         {char*}
%destructor float_type_specifier        { }
%destructor integer_type_specifier      { }
%destructor object_type_specifier       { FREEMEM($$); }
%destructor type_qualifier              { }
%destructor type_qualifier_list         { }
%destructor scalar_constant             { FREEMEM($$); }
%destructor integer_literal             { FREEMEM($$); }
%destructor float_literal               { FREEMEM($$); }
%destructor hex_literal                 { FREEMEM($$); }
%destructor string_literal              { FREEMEM($$); }
%destructor asterisk_postfix            { FREEMEM($$); }
%destructor array_postfix               { FREEMEM($$); }
%destructor array_postfix_elem          { FREEMEM($$); }
%destructor declarator                  { FREEMEM($$); }
%destructor class_name                  { FREEMEM($$); }
%destructor cnick                       { FREEMEM($$); }

void_type_specifier ::= VOID.
va_list_specifier         ::= VA_LIST.
integer_type_specifier(A) ::= INT8_T.    { A = KW_INT8_T; }
integer_type_specifier(A) ::= INT16_T.   { A = KW_INT16_T; }
integer_type_specifier(A) ::= INT32_T.   { A = KW_INT32_T; }
integer_type_specifier(A) ::= INT64_T.   { A = KW_INT64_T; }
integer_type_specifier(A) ::= UINT8_T.   { A = KW_UINT8_T; }
integer_type_specifier(A) ::= UINT16_T.  { A = KW_UINT16_T; }
integer_type_specifier(A) ::= UINT32_T.  { A = KW_UINT32_T; }
integer_type_specifier(A) ::= UINT64_T.  { A = KW_UINT64_T; }
integer_type_specifier(A) ::= CHAR.      { A = KW_CHAR; }
integer_type_specifier(A) ::= SHORT.     { A = KW_SHORT; }
integer_type_specifier(A) ::= INT.       { A = KW_INT; }
integer_type_specifier(A) ::= LONG.      { A = KW_LONG; }
integer_type_specifier(A) ::= SIZE_T.    { A = KW_SIZE_T; }
integer_type_specifier(A) ::= BOOL_T.    { A = KW_BOOL_T; }
float_type_specifier(A) ::= FLOAT.   { A = KW_FLOAT; }
float_type_specifier(A) ::= DOUBLE.  { A = KW_DOUBLE; }

integer_type(A) ::= integer_type_specifier(B).
{
    A = (CFCBase*)CFCType_new_integer(0, B);
}

integer_type(A) ::= CONST integer_type_specifier(B).
{
    A = (CFCBase*)CFCType_new_integer(CFCTYPE_CONST, B);
}

float_type(A) ::= float_type_specifier(B).
{
    A = (CFCBase*)CFCType_new_float(0, B);
}

float_type(A) ::= CONST float_type_specifier(B).
{
    A = (CFCBase*)CFCType_new_float(CFCTYPE_CONST, B);
}

va_list_type(A) ::= va_list_specifier.
{
    A = (CFCBase*)CFCType_new_va_list();
}

arbitrary_type(A) ::= ARBITRARY.
{
    A = (CFCBase*)CFCType_new_arbitrary(CFCParser_get_parcel(),
                                        CFCParser_current_state->text);
}

object_type(A) ::= object_type_specifier(B) ASTERISK.
{
    A = (CFCBase*)CFCType_new_object(0, CFCParser_get_parcel(), B, 1);
}

object_type(A) ::= type_qualifier_list(B) object_type_specifier(C) ASTERISK.
{
    A = (CFCBase*)CFCType_new_object(B, CFCParser_get_parcel(), C, 1);
}

object_type_specifier(A) ::= CLASS_NAME_COMPONENT.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}

object_type_specifier(A) ::= PREFIXED_OBJECT_TYPE_SPECIFIER.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}

type_qualifier(A) ::= CONST.       { A = CFCTYPE_CONST; }
type_qualifier(A) ::= NULLABLE.    { A = CFCTYPE_NULLABLE; }
type_qualifier(A) ::= INCREMENTED. { A = CFCTYPE_INCREMENTED; }
type_qualifier(A) ::= DECREMENTED. { A = CFCTYPE_DECREMENTED; }

type_qualifier_list(A) ::= type_qualifier(B).               { A = B; }
type_qualifier_list(A) ::= type_qualifier_list CONST.       { A |= CFCTYPE_CONST; }
type_qualifier_list(A) ::= type_qualifier_list NULLABLE.    { A |= CFCTYPE_NULLABLE; }
type_qualifier_list(A) ::= type_qualifier_list INCREMENTED. { A |= CFCTYPE_INCREMENTED; }
type_qualifier_list(A) ::= type_qualifier_list DECREMENTED. { A |= CFCTYPE_DECREMENTED; }

asterisk_postfix(A) ::= ASTERISK.
{
    A = CFCUtil_strdup("*");
}
asterisk_postfix(A) ::= asterisk_postfix(B) ASTERISK.
{
    A = CFCUtil_cat(B, "*", NULL);
}

array_postfix_elem(A) ::= LEFT_SQUARE_BRACKET RIGHT_SQUARE_BRACKET.
{
    A = CFCUtil_strdup("[]");
}
array_postfix_elem(A) ::= LEFT_SQUARE_BRACKET integer_literal(B) RIGHT_SQUARE_BRACKET.
{
    A = CFCUtil_cat(CFCUtil_strdup(""), "[", B, "]", NULL);
}

array_postfix(A) ::= array_postfix_elem(B). 
{ 
    A = B; 
}
array_postfix(A) ::= array_postfix(B) array_postfix_elem(C).
{
    A = CFCUtil_cat(B, C, NULL);
}

scalar_constant(A) ::= hex_literal(B).     { A = B; }
scalar_constant(A) ::= float_literal(B).   { A = B; }
scalar_constant(A) ::= integer_literal(B). { A = B; }
scalar_constant(A) ::= string_literal(B).  { A = B; }
scalar_constant(A) ::= TRUE.     { A = CFCUtil_strdup("true"); }
scalar_constant(A) ::= FALSE.    { A = CFCUtil_strdup("false"); }
scalar_constant(A) ::= NULL.     { A = CFCUtil_strdup("NULL"); }

integer_literal(A) ::= INTEGER_LITERAL.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}
float_literal(A) ::= FLOAT_LITERAL.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}
hex_literal(A) ::= HEX_LITERAL.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}
string_literal(A) ::= STRING_LITERAL.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}

declarator(A) ::= IDENTIFIER.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}

param_variable(A) ::= type(B) declarator(C).
{
    A = (CFCBase*)CFCVariable_new(CFCParser_get_parcel(), NULL, NULL, 
                                  NULL, C, (CFCType*)B);
}

param_list(A) ::= LEFT_PAREN RIGHT_PAREN.
{
    A = (CFCBase*)CFCParamList_new(false);
}
param_list(A) ::= LEFT_PAREN param_list_elems(B) RIGHT_PAREN.
{
    A = B;
}
param_list(A) ::= LEFT_PAREN param_list_elems(B) COMMA ELLIPSIS RIGHT_PAREN.
{
    A = B;
    CFCParamList_set_variadic((CFCParamList*)A, true);
}
param_list_elems(A) ::= param_list_elems(B) COMMA param_variable(C).
{
    A = B;
    CFCParamList_add_param((CFCParamList*)A, (CFCVariable*)C, NULL);
}
param_list_elems(A) ::= param_list_elems(B) COMMA param_variable(C) EQUALS scalar_constant(D).
{
    A = B;
    CFCParamList_add_param((CFCParamList*)A, (CFCVariable*)C, D);
}
param_list_elems(A) ::= param_variable(B).
{
    A = (CFCBase*)CFCParamList_new(false);
    CFCParamList_add_param((CFCParamList*)A, (CFCVariable*)B, NULL);
}
param_list_elems(A) ::= param_variable(B) EQUALS scalar_constant(C).
{
    A = (CFCBase*)CFCParamList_new(false);
    CFCParamList_add_param((CFCParamList*)A, (CFCVariable*)B, C);
}

docucomment(A) ::= DOCUCOMMENT.
{
    A = (CFCBase*)CFCDocuComment_parse(CFCParser_current_state->text);
}

class_name(A) ::= CLASS_NAME_MULTI.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}

class_name(A) ::= CLASS_NAME_COMPONENT.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}

cnick(A) ::= CNICK CLASS_NAME_COMPONENT.
{
    A = CFCUtil_strdup(CFCParser_current_state->text);
}

