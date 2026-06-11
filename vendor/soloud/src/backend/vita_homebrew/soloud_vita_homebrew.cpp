/*
SoLoud Vita homebrew output backend
Copyright (c) 2017 Ilya Zhuravlev

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.

   3. This notice may not be removed or altered from any source
   distribution.
*/

#include <atomic>
#include <new>
#include <string.h>

#include "soloud.h"
#include "soloud_thread.h"

#include <psp2/audioout.h>
#include <psp2/kernel/threadmgr.h>
#include <stdio.h>

#if !defined(WITH_VITA_HOMEBREW)

namespace SoLoud
{
	result vita_homebrew_init(Soloud *aSoloud, unsigned int aFlags, unsigned int aSamplerate, unsigned int aBuffer)
	{
		return NOT_IMPLEMENTED;
	}
};

#else

namespace SoLoud
{
	struct VitaData {
		std::atomic<bool> done;
		int port;
		unsigned samples;
		Soloud *soloud;
		int tid;
		int16_t *buffer[2];
	};

	static void vita_cleanup(Soloud *aSoloud) {
		if (!aSoloud->mBackendData)
			return;

		VitaData *data = (VitaData*)aSoloud->mBackendData;
		data->done = true;

		if (data->tid >= 0)
		{
			sceKernelWaitThreadEnd(data->tid, NULL, NULL);
			sceKernelDeleteThread(data->tid);
		}
		sceAudioOutReleasePort(data->port);

		delete[] data->buffer[0];
		delete[] data->buffer[1];

		delete data;
		aSoloud->mBackendData = NULL;
	}

	static int vita_thread(SceSize args, void *argp) {
		VitaData *data = *(VitaData**)argp;

		int buf_id = 0;

		while (!data->done) {
			data->soloud->mixSigned16(data->buffer[buf_id], data->samples);
			sceAudioOutOutput(data->port, data->buffer[buf_id]);

			buf_id ^= 1;
		}

		return 0;
	}

	result vita_homebrew_init(Soloud *aSoloud, unsigned int aFlags, unsigned int aSamplerate, unsigned int aBuffer, unsigned int aChannels)
	{
		if (aSamplerate != 44100 || aChannels != 2)
			return INVALID_PARAMETER;

		int port = sceAudioOutOpenPort(SCE_AUDIO_OUT_PORT_TYPE_BGM, aBuffer, aSamplerate, SCE_AUDIO_OUT_MODE_STEREO);
		if (port < 0)
			return INVALID_PARAMETER;

		VitaData *data = new (std::nothrow) VitaData();
		if (!data)
		{
			sceAudioOutReleasePort(port);
			return OUT_OF_MEMORY;
		}
		data->port = port;
		data->samples = aBuffer;
		data->soloud = aSoloud;
		data->tid = -1;
		data->buffer[0] = new (std::nothrow) int16_t[aChannels * aBuffer];
		data->buffer[1] = new (std::nothrow) int16_t[aChannels * aBuffer];
		if (!data->buffer[0] || !data->buffer[1])
		{
			delete[] data->buffer[0];
			delete[] data->buffer[1];
			delete data;
			sceAudioOutReleasePort(port);
			return OUT_OF_MEMORY;
		}
		aSoloud->mBackendData = data;
		aSoloud->mBackendCleanupFunc = vita_cleanup;

		aSoloud->postinit_internal(aSamplerate, data->samples * aChannels, aFlags, aChannels);

		data->tid = sceKernelCreateThread("soloud audio output", vita_thread, 0x10000100, 0x10000, 0, 0, NULL);
		if (data->tid < 0)
		{
			vita_cleanup(aSoloud);
			return INVALID_PARAMETER;
		}
		if (sceKernelStartThread(data->tid, sizeof(data), &data) < 0)
		{
			sceKernelDeleteThread(data->tid);
			data->tid = -1;
			vita_cleanup(aSoloud);
			return INVALID_PARAMETER;
		}

		return 0;
	}
};

#endif
