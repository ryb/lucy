#define C_LUCY_TESTINSTREAM
#define C_LUCY_INSTREAM
#define C_LUCY_FILEWINDOW
#include <stdlib.h>
#include <time.h>

#include "Lucy/Util/ToolSet.h"
#include "Lucy/Test.h"
#include "Lucy/Test/TestUtils.h"
#include "Lucy/Test/Store/TestIOChunks.h"
#include "Lucy/Store/InStream.h"
#include "Lucy/Store/OutStream.h"
#include "Lucy/Store/RAMFile.h"
#include "Lucy/Store/RAMFileHandle.h"
#include "Lucy/Util/NumberUtils.h"

static void
test_Read_Write_Bytes(TestBatch *batch)
{
    RAMFile    *file      = RAMFile_new(NULL, false);
    OutStream  *outstream = OutStream_open((Obj*)file);
    InStream   *instream;
    char        buf[4];

    OutStream_Write_Bytes(outstream, "foo", 4);
    OutStream_Close(outstream);

    instream = InStream_open((Obj*)file);
    InStream_Read_Bytes(instream, buf, 4);
    ASSERT_TRUE(batch, strcmp(buf, "foo") == 0, "Read_Bytes Write_Bytes");

    DECREF(instream);
    DECREF(outstream);
    DECREF(file);
}

static void
test_Buf(TestBatch *batch)
{
    RAMFile    *file      = RAMFile_new(NULL, false);
    OutStream  *outstream = OutStream_open((Obj*)file);
    InStream   *instream;
    size_t      size = IO_STREAM_BUF_SIZE * 2 + 5;
    u32_t i;
    char       *buf;

    for (i = 0; i < size; i++) {
        OutStream_Write_U8(outstream, 'a');
    }
    OutStream_Close(outstream);

    instream = InStream_open((Obj*)file);
    buf = InStream_Buf(instream, 5);
    ASSERT_INT_EQ(batch, instream->limit - buf, IO_STREAM_BUF_SIZE, 
        "Small request bumped up");

    buf += IO_STREAM_BUF_SIZE - 10; /* 10 bytes left in buffer. */
    InStream_Advance_Buf(instream, buf);

    buf = InStream_Buf(instream, 10);
    ASSERT_INT_EQ(batch, instream->limit - buf, 10, 
        "Exact request doesn't trigger refill");

    buf = InStream_Buf(instream, 11);
    ASSERT_INT_EQ(batch, instream->limit - buf, IO_STREAM_BUF_SIZE, 
        "Requesting over limit triggers refill");

    {
        size_t expected = InStream_Length(instream) - InStream_Tell(instream);
        buf = InStream_Buf(instream, 100000); 
        ASSERT_INT_EQ(batch, instream->limit - buf, expected,
            "Requests greater than file size get pared down");
    }

    DECREF(instream);
    DECREF(outstream);
    DECREF(file);
}

void
TestIOChunks_run_tests()
{
    TestBatch   *batch     = Test_new_batch("TestIOChunks", 5, NULL);

    srand((unsigned int)time((time_t*)NULL));
    PLAN(batch);

    test_Read_Write_Bytes(batch);
    test_Buf(batch);
    
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
