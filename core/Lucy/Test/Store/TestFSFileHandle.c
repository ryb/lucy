#include <stdio.h> /* for remove() */

#define C_LUCY_CHARBUF
#define C_LUCY_FSFILEHANDLE
#define C_LUCY_FILEWINDOW
#include "Lucy/Util/ToolSet.h"

#ifdef CHY_HAS_UNISTD_H 
  #include <unistd.h> /* close */
#elif defined(CHY_HAS_IO_H)
  #include <io.h> /* close */
#endif

#define CHAZ_USE_SHORT_NAMES
#include "Charmonizer/Test.h"
#include "Lucy/Test/Store/TestFSFileHandle.h"
#include "Lucy/Store/FSFileHandle.h"
#include "Lucy/Store/FileWindow.h"

static CharBuf test_filename = ZCB_LITERAL("_fsfh_test_file");

static void
test_open(TestBatch *batch)
{
    FSFileHandle *fh;

    remove((char*)CB_Get_Ptr8(&test_filename));

    Err_set_error(NULL);
    fh = FSFH_open(&test_filename, FH_READ_ONLY);
    ASSERT_TRUE(batch, fh == NULL, 
        "open() with FH_READ_ONLY on non-existent file returns NULL");
    ASSERT_TRUE(batch, Err_get_error() != NULL,
        "open() with FH_READ_ONLY on non-existent file sets error");

    Err_set_error(NULL);
    fh = FSFH_open(&test_filename, FH_WRITE_ONLY);
    ASSERT_TRUE(batch, fh == NULL, 
        "open() without FH_CREATE returns NULL");
    ASSERT_TRUE(batch, Err_get_error() != NULL,
        "open() without FH_CREATE sets error");

    Err_set_error(NULL);
    fh = FSFH_open(&test_filename, FH_CREATE);
    ASSERT_TRUE(batch, fh == NULL, 
        "open() without FH_WRITE_ONLY returns NULL");
    ASSERT_TRUE(batch, Err_get_error() != NULL,
        "open() without FH_WRITE_ONLY sets error");

    Err_set_error(NULL);
    fh = FSFH_open(&test_filename, FH_CREATE | FH_WRITE_ONLY | FH_EXCLUSIVE);
    ASSERT_TRUE(batch, fh && FSFH_Is_A(fh, FSFILEHANDLE), "open() succeeds");
    ASSERT_TRUE(batch, Err_get_error() == NULL, "open() no errors");
    FSFH_Write(fh, "foo", 3);
    if (!FSFH_Close(fh)) { RETHROW(INCREF(Err_get_error())); }
    DECREF(fh);

    Err_set_error(NULL);
    fh = FSFH_open(&test_filename, FH_CREATE | FH_WRITE_ONLY | FH_EXCLUSIVE);
    ASSERT_TRUE(batch, fh == NULL, "FH_EXCLUSIVE blocks open()");
    ASSERT_TRUE(batch, Err_get_error() != NULL,
        "FH_EXCLUSIVE blocks open(), sets error");

    Err_set_error(NULL);
    fh = FSFH_open(&test_filename, FH_CREATE | FH_WRITE_ONLY);
    ASSERT_TRUE(batch, fh && FSFH_Is_A(fh, FSFILEHANDLE), 
        "open() for append");
    ASSERT_TRUE(batch, Err_get_error() == NULL, 
        "open() for append -- no errors");
    FSFH_Write(fh, "bar", 3);
    if (!FSFH_Close(fh)) { RETHROW(INCREF(Err_get_error())); }
    DECREF(fh);

    Err_set_error(NULL);
    fh = FSFH_open(&test_filename, FH_READ_ONLY);
    ASSERT_TRUE(batch, fh && FSFH_Is_A(fh, FSFILEHANDLE), "open() read only");
    ASSERT_TRUE(batch, Err_get_error() == NULL, 
        "open() read only -- no errors");
    DECREF(fh);
    
    remove((char*)CB_Get_Ptr8(&test_filename));
}

static void
test_Read_Write(TestBatch *batch)
{
    FSFileHandle *fh;
    const char *foo = "foo";
    const char *bar = "bar";
    char buffer[12];
    char *buf = buffer;

    remove((char*)CB_Get_Ptr8(&test_filename));
    fh = FSFH_open(&test_filename, 
        FH_CREATE | FH_WRITE_ONLY | FH_EXCLUSIVE);

    ASSERT_TRUE(batch, FSFH_Length(fh) == I64_C(0), "Length initially 0");
    ASSERT_TRUE(batch, FSFH_Write(fh, foo, 3), "Write returns success");
    ASSERT_TRUE(batch, FSFH_Length(fh) == I64_C(3), "Length after Write");
    ASSERT_TRUE(batch, FSFH_Write(fh, bar, 3), "Write returns success");
    ASSERT_TRUE(batch, FSFH_Length(fh) == I64_C(6), "Length after 2 Writes");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, FSFH_Read(fh, buf, 0, 2), 
        "Reading from a write-only handle returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Reading from a write-only handle sets error");
    if (!FSFH_Close(fh)) { RETHROW(INCREF(Err_get_error())); }
    DECREF(fh);

    /* Reopen for reading. */
    Err_set_error(NULL);
    fh = FSFH_open(&test_filename, FH_READ_ONLY);

    ASSERT_TRUE(batch, FSFH_Length(fh) == I64_C(6), "Length on Read");
    ASSERT_TRUE(batch, FSFH_Read(fh, buf, 0, 6), "Read returns success");
    ASSERT_TRUE(batch, strncmp(buf, "foobar", 6) == 0, "Read/Write");
    ASSERT_TRUE(batch, FSFH_Read(fh, buf, 2, 3), "Read returns success");
    ASSERT_TRUE(batch, strncmp(buf, "oba", 3) == 0, "Read with offset");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, FSFH_Read(fh, buf, -1, 4),
        "Read() with a negative offset returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Read() with a negative offset sets error");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, FSFH_Read(fh, buf, 6, 1),
        "Read() past EOF returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Read() past EOF sets error");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, FSFH_Write(fh, foo, 3), 
        "Writing to a read-only handle returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Writing to a read-only handle sets error");

    DECREF(fh);
    remove((char*)CB_Get_Ptr8(&test_filename));
}

static void
test_Close(TestBatch *batch)
{
    FSFileHandle *fh;
    bool_t        result;

    remove((char*)CB_Get_Ptr8(&test_filename));
    fh = FSFH_open(&test_filename, 
        FH_CREATE | FH_WRITE_ONLY | FH_EXCLUSIVE);
    ASSERT_TRUE(batch, FSFH_Close(fh), "Close returns true for write-only");
    DECREF(fh);

    /* Simulate an OS error when closing the file descriptor.  This
     * approximates what would happen if, say, we run out of disk space. */
    remove((char*)CB_Get_Ptr8(&test_filename));
    fh = FSFH_open(&test_filename, 
        FH_CREATE | FH_WRITE_ONLY | FH_EXCLUSIVE);
    close(fh->fd);
    fh->fd = -1;
    Err_set_error(NULL);
    result = FSFH_Close(fh);
    ASSERT_FALSE(batch, result, "Failed Close() returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Failed Close() sets Err_error");
    DECREF(fh);

    fh = FSFH_open(&test_filename, FH_READ_ONLY);
    ASSERT_TRUE(batch, FSFH_Close(fh), "Close returns true for read-only");

    DECREF(fh);
    remove((char*)CB_Get_Ptr8(&test_filename));
}

static void
test_Window(TestBatch *batch)
{
    FSFileHandle *fh;
    FileWindow *window = FileWindow_new();
    u32_t i;

    remove((char*)CB_Get_Ptr8(&test_filename));
    fh = FSFH_open(&test_filename, 
        FH_CREATE | FH_WRITE_ONLY | FH_EXCLUSIVE);
    for (i = 0; i < 1024; i++) {
        FSFH_Write(fh, "foo ", 4);
    }
    if (!FSFH_Close(fh)) { RETHROW(INCREF(Err_get_error())); }

    /* Reopen for reading. */
    DECREF(fh);
    fh = FSFH_open(&test_filename, FH_READ_ONLY);
    if (!fh) { RETHROW(INCREF(Err_get_error())); }

    Err_set_error(NULL);
    ASSERT_FALSE(batch, FSFH_Window(fh, window, -1, 4),
        "Window() with a negative offset returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Window() with a negative offset sets error");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, FSFH_Window(fh, window, 4000, 1000),
        "Window() past EOF returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Window() past EOF sets error");

    ASSERT_TRUE(batch, FSFH_Window(fh, window, 1021, 2), 
        "Window() returns true");
    ASSERT_TRUE(batch, 
        strncmp(window->buf + window->offset + 1021, "oo", 2) == 0, 
        "Window()");

    ASSERT_TRUE(batch, FSFH_Release_Window(fh, window), 
        "Release_Window() returns true");
    ASSERT_TRUE(batch, window->buf == NULL, "Release_Window() resets buf");
    ASSERT_TRUE(batch, window->offset == 0, "Release_Window() resets offset");
    ASSERT_TRUE(batch, window->len == 0, "Release_Window() resets len");

    DECREF(window);
    DECREF(fh);
    remove((char*)CB_Get_Ptr8(&test_filename));
}

void
TestFSFH_run_tests()
{
    TestBatch *batch = Test_new_batch("TestFSFileHandle", 46, NULL);

    PLAN(batch);
    test_open(batch);
    test_Read_Write(batch);
    test_Close(batch);
    test_Window(batch);

    batch->destroy(batch);
}

/* Copyright 2009 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
