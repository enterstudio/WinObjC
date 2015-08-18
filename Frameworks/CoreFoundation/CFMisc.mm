//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#import <CoreFoundation/CoreFoundation.h>
#include <Windows.h>

#include <Windows.Foundation.h>
#include <Windows.Security.Cryptography.h>
#include <wrl\wrappers\corewrappers.h>
#undef interface

#include <Starboard.h>

#ifndef __ISLANDWOOD_COMPAT
#include <sys/types.h>
#endif

using namespace ABI::Windows::Foundation;
using namespace Microsoft::WRL;
using namespace Microsoft::WRL::Wrappers;

extern "C" void *_OBJC_CLASS_CFConstantString = NULL;
static ABI::Windows::Security::Cryptography::ICryptographicBufferStatics* bufferStatics = nullptr;

COREFOUNDATION_EXPORT extern "C" uint32_t arc4random()
{
    if (bufferStatics == nullptr) {
        if (!SUCCEEDED(GetActivationFactory(HStringReference(L"Windows.Security.Cryptography.CryptographicBuffer").Get(), &bufferStatics))) {
            EbrDebugLog("Unable to get CryptographicBuffer interface!\n");
        }
    }

    UINT32 randResult = 0;
    if(!SUCCEEDED(bufferStatics->GenerateRandomNumber(&randResult))) {
        EbrDebugLog("Unable to get random number!\n");
    }
    return randResult;

    return (uint32_t)randResult;
}

COREFOUNDATION_EXPORT extern "C" int usleep(long secs)
{
    Sleep(secs * 1000);
    return 0;
}

COREFOUNDATION_EXPORT extern "C" int sysctlbyname(const char *name, void *out, size_t *outSize, const void *, size_t)
{
    if ( strcmp(name, "hw.machine") == 0 ) {
        const int required = 8;
        if ( outSize ) {
            // If there's no buffer, we have to return the nr. of bytes required for this response.
            *outSize = !out ? required : min(*outSize, required);
        } else {
            return -1;
        }

        if ( out ) strncpy((char *) out, "winobjc", *outSize); // outsize is <= required here
        return *outSize < required ? ENOMEM : 0;
    }
    return -1;
}

CFStringRef CFCopyDescription(CFTypeRef ref)
{
    return (CFStringRef) @"Desc";
}
