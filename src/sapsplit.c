// SAPSPLIT v0.1 by VinsCool

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <limits.h>

#include "sapsplit.h"
//#include "zx2.h"
#include "./ZX02/zx02.h"


// Exit the program, an optional code may be provided for handling errors
void Quit(TStatusCode statusCode, const char* argument)
{
	switch (statusCode)
	{
	case SUCCESSFUL:
		fprintf(stderr, "%s\n\n", argument? argument : "Success!");
		break;
		
	case INPUT_ERROR:
		fprintf(stderr, "Could not open '%s'\n%s\n\n", argument ? argument : "", argument ?
		"No such file or directory" : "Missing argument: [-i] [filename]");
		break;
		
	case OUTPUT_ERROR:
		fprintf(stderr, "Could not write '%s'\n%s\n\n", argument ? argument : "", argument ?
		"No such file or directory" : "Missing argument: [-o] [filename]");
		break;
		
	case ARGUMENT_ERROR:
		fprintf(stderr, "Invalid argument: '%s'\n\n", argument);
		break;
		
	case PARAMETER_ERROR:
		fprintf(stderr, "Invalid parameter: '%s'\n\n", argument);
		break;
		
	case HELP_SCREEN:
		fprintf(stderr, "[SAPSPLIT v0.1 by VinsCool]\n\n"
		"Usage: '%s [-argument] [parameter]'\n\n"
		"Multiple arguments may be used at once, in no particular order\n"
		"Optional parameters may also be required for specific purposes\n\n"
		"[-i] [filename] Input file to be processed\n"
		"[-o] [filename] Output file(s) to be saved\n"
		"[-h] Display this screen and exit the program\n\n", argument);
		break;
		
	case INVALID_DATA:
		fprintf(stderr, "Invalid data: '%s'\n\n", argument);
		break;
		
	case NOT_ENOUGH_MEMORY:
		fprintf(stderr, "Error: Could not create new data due to insufficient memory\n\n");
		break;
		
	default:
		fprintf(stderr, "%s\n\n", argument ?
		argument : "Error: Unknown program status, something wrong occured");
	}
	
	fprintf(stderr, "The status code of '%i' was returned upon exit\n\n", statusCode);
	exit(statusCode);
}

void FindDuplicateChunk(TSapSplitState* pState, TChunkSection* pChunkFrom, TChunkSection* pChunkTo)
{
	if (!pChunkFrom || !pChunkTo)
		Quit(FAILURE, NULL);
		
	if (pChunkFrom == pChunkTo)
	{
		//printf("Skipped comparison: Chunk could not be compared to itself\n");
		return;
	}
	
	if (pChunkFrom->reference)
	{
		//printf("Skipped comparison: Chunk was already identified as a duplicate\n");
		return;
	}
		
	if (pChunkFrom->size != pChunkTo->size)
	{
		//printf("Skipped comparison: Chunk size mismatch\n\n");
		return;
	}
	
	if (!(memcmp(pChunkFrom->buffer, pChunkTo->buffer, pChunkFrom->size)))
	{
		printf("Chunk [%02X][%02X] is a duplicate of Chunk [%02X][%02X]\n",
			pChunkTo->channel, pChunkTo->section, pChunkFrom->channel, pChunkFrom->section);
		
		pChunkTo->reference = pChunkFrom;
	}
	
}

void WriteChunk(TSapSplitState* pState, TChunkSection* pChunk)
{
	if (!pChunk)
		Quit(FAILURE, NULL);
	
	TChunkSection* pChunkChain;	// = pChunk->linked;

	printf("Chunk %02X [%02X][%02X] ", pChunk->index, pChunk->channel, pChunk->section);
	
	if (pChunk->reference)
	{
		printf("was skipped, a reference was found in Offset %02X\n", pChunk->reference->offset);

		if (pChunkChain = pChunk->reference->linked)
		//if (pChunkChain = pChunk->linked)
		{
			printf("-> Linked to Chunk ");
			
			while (pChunkChain)
			{
				printf("%02X, ", pChunkChain->offset);
				pChunkChain = pChunkChain->linked;
			}
			
			printf("\n");
		}

		return;
	}
	
	printf("was created, a reference was added in Offset %02X\n", pChunk->offset);
	
	if (pChunkChain = pChunk->linked)
	{
		printf("-> Linked to Chunk ");
		
		while (pChunkChain)
		{
			printf("%02X, ", pChunkChain->offset);
			pChunkChain = pChunkChain->linked;
		}
		
		printf("\n");
	}

	// Create the output filename appended with additional infos as an extention
	char fileName[1024];
	sprintf(fileName, "%s.%X_%02X", pState->outputName, pChunk->channel, pChunk->section);
	
	// Open the output file
	FILE* out = fopen(fileName, "wb");
	
	if (!out)
		Quit(OUTPUT_ERROR, fileName);
	
	fseek(out, 0, SEEK_SET);
	
	// Write the entire buffer to the file
	size_t writeCount = fwrite(pChunk->buffer, 1, pChunk->size, out);
	
	// Close the file once it is written
	fclose(out);
	
	printf("-> File saved as '%s' (%i bytes)\n", fileName, pChunk->size);
	
	pState->effectiveSize += pChunk->size;
	pState->effectiveCount++;
	
	// If there is a mismatch between the bytes written and expected, abort the procedure
	if (writeCount != pChunk->size)
		Quit(FAILURE, "Fatal error: The number of bytes written did not match the expected count");
}

TChunkSection* DeleteChunk(TChunkSection* pChunk)
{
	if (pChunk)
	{
		free(pChunk);
		pChunk = NULL;
	}
	
	return pChunk;
}

TChunkSection* CreateChunk(BYTE* buffer, UINT size, UINT offset, UINT index, UINT channel, UINT section)
{
	TChunkSection* pChunk;

	if (!(pChunk = malloc(sizeof(TChunkSection))))
		Quit(NOT_ENOUGH_MEMORY, NULL);
	
	pChunk->reference = NULL;
	pChunk->linked = NULL;
	pChunk->buffer = buffer;
	pChunk->size = size;
	pChunk->offset = offset;
	pChunk->index = index;
	pChunk->channel = channel;
	pChunk->section = section;
	
	UINT byteCount = 0;
	
	for (UINT i = 0; i < size; i++)
		byteCount += (pChunk->buffer[0] == pChunk->buffer[i]);
	
	if (byteCount == size)
		printf("Warning: Chunk [%02X][%02X] filled with $%02X bytes\n", channel, section, pChunk->buffer[0]);
	
	return pChunk;
}

void DeleteAllChunks(TSapSplitState* pState)
{
	for (int i = 0; i < MAX_CHUNK_COUNT; i++)
		pState->sectionStream[i] = DeleteChunk(pState->sectionStream[i]);
}

// Split each channel to individual byte stream
BYTE* CreateStream(BYTE* fileBuffer, UINT fileSize, UINT channelCount, UINT channelSize, UINT offset)
{
	UINT frame = 0;
	BYTE* pStream;
	
	if (!(pStream = malloc(sizeof(BYTE[channelSize]))))
		Quit(NOT_ENOUGH_MEMORY, NULL);
	
	while (offset < fileSize)
	{
		pStream[frame++] = fileBuffer[offset];
		offset += channelCount;
	}
	
	return pStream;
}

BYTE* DeleteStream(BYTE* pStream)
{
	if (pStream)
	{
		free(pStream);
		pStream = NULL;
	}
	
	return pStream;
}

void DeleteAllStreams(TSapSplitState* pState)
{
	for (int i = 0; i < MAX_STREAM_COUNT; i++)
		pState->channelStream[i] = DeleteStream(pState->channelStream[i]);
}

void ProcessArguments(TSapSplitState* pState, int argc, char** argv)
{	
	char* option = NULL;
	pState->optionMode = UNDEFINED;
	pState->channelCount = MONO_POKEY;
	pState->sectionCount = MIN_SECTION_COUNT;
	pState->optimisationMode = NO_OPTIMISATION;
	pState->compressionMode = ZX2;
	
	// Allocate the channel stream memory using the stream count for reference
	if (!(pState->channelStream = calloc(MAX_STREAM_COUNT, sizeof(BYTE*))))
		Quit(NOT_ENOUGH_MEMORY, NULL);
	
	// Allocate the section stream memory using the chunk count for reference
	if (!(pState->sectionStream = calloc(MAX_CHUNK_COUNT, sizeof(TChunkSection*))))
		Quit(NOT_ENOUGH_MEMORY, NULL);

	// Parse command line arguments and parameters
	for (int i = 1; i < argc; i++)
	{
		if (argv[i][0] == '-' && argv[i][2] == 0)
		{
			switch (argv[i][1])
			{
			case 'c':
				pState->chunkStream = argv[++i];
				continue;
			
			case 'i':
				pState->inputName = argv[++i];
				continue;
				
			case 'o':
				pState->outputName = argv[++i];
				continue;
				
			case 's':
				pState->channelCount = STEREO_POKEY;
				continue;
				
			case 'm':
				option = argv[++i];
					
				if (!strcmp(option, "split"))
					pState->optionMode = SPLIT;
				else if (!strcmp(option, "merge"))
					pState->optionMode = MERGE;
				else if (!strcmp(option, "concatenate"))
					pState->optionMode = CONCATENATE;
				else if (!strcmp(option, "analyse"))
					pState->optionMode = ANALYSE;
				else
					break;
					//optionMode = UNDEFINED;
				continue;
		
			case 'h':
				Quit(HELP_SCREEN, argv[0]);
			}
		}
		
		// Anything reaching this line is assumed to be an invalid argument
		Quit(ARGUMENT_ERROR, argv[i]);
	}

	// Verify if the input and output filenames are valid before continuing further
	if (!pState->inputName || strlen(pState->inputName) < 1)
		Quit(INPUT_ERROR, pState->inputName);

	if (!pState->outputName || strlen(pState->outputName) < 1)
		Quit(OUTPUT_ERROR, pState->outputName);
}

void LoadInputFile(TSapSplitState* pState)
{
	// Open the input file
	FILE* in = fopen(pState->inputName, "rb");
	
	if (!in)
		Quit(INPUT_ERROR, pState->inputName);
		
	// Skip SAP header
	char header[128];
	
	fseek(in, 0, SEEK_SET);
	size_t pos = ftell(in);
	
	while(0 != fgets(header, 80, in))
	{
		size_t ln = strlen(header);
		
		if( ln < 1 || header[ln-1] != '\n' )
			break;
		
		pos = ftell(in);
		
		if( (ln == 2 && header[ln-2] == '\r') || (ln == 1) )
			break;
	}
	
	// Read all data
	fseek(in, pos, SEEK_SET);
	pos = ftell(in);
	fseek(in, 0, SEEK_END);
	
	// Identify the file size, and reject anything not matching a multiple of streamCount
	if ((pState->fileSize = (ftell(in) - pos)) % pState->channelCount)
		Quit(INVALID_DATA, pState->inputName);
	
	fseek(in, pos, SEEK_SET);
	
	// Allocate the file buffer memory using the framecount for reference
	if (!(pState->fileBuffer = (BYTE*)malloc(pState->fileSize * sizeof(BYTE))))
		Quit(NOT_ENOUGH_MEMORY, NULL);
	
	// Load the entire file into the buffer
	size_t readCount = fread(pState->fileBuffer, sizeof(BYTE), pState->fileSize, in);
	
	// Close the file once it is read
	fclose(in);
	
	// If there is a mismatch between the bytes read and identified, abort the procedure
	if (readCount != pState->fileSize)
		Quit(FAILURE, "Fatal error: The number of bytes read did not match the expected count");
	
	// Set the number of bytes to process for each channel stream
	if (!(pState->channelSize = pState->fileSize / pState->channelCount))
		Quit(FAILURE, "Fatal Error: A size of 0 could not be used");
	
	printf("Loaded '%s'\n", pState->inputName);
	printf("Effective Size: %u Bytes\n", pState->fileSize);
}

// Analyse the streamSize to find the optimal section size per channel stream
void AnalyseStreams(TSapSplitState* pState)
{	
	UINT blockCount = 0;
	UINT blockSize[MAX_SECTION_COUNT];
	memset(&blockSize, 0, sizeof(UINT));
	
	printf("Channel Count: %u\n", pState->channelCount);
	printf("Frame Count: %u\n", pState->channelSize);
	
	//pState->optimisationMode = AUDC;
	SplitStreams(pState);
	
	if (pState->chunkStream)
	{
		char* offset = pState->chunkStream;
		UINT maxOffset = strlen(pState->chunkStream);
		int frameCount = pState->channelSize;
		
		printf("Chunk Stream:\n");
		
		for (blockCount; blockCount < MAX_SECTION_COUNT; blockCount++)
		{
			if (maxOffset == 0)
				break;
			
			blockSize[blockCount] = atoi(offset);
			frameCount -= blockSize[blockCount];
			
			printf("[%u][%u], remainder: %i frames\n", blockCount, blockSize[blockCount], frameCount);
			
			if (frameCount < 0)
				Quit(FAILURE, "Fatal error: The number of frames is shorter than expected");
			
			while (maxOffset > 0)
			{
				offset++;
				maxOffset--;
				
				if (*offset == ',' || *offset == ' ')
				{
					offset++;
					maxOffset--;
					break;
				}
			}
		}

		if (frameCount > 0)
			Quit(FAILURE, "Fatal error: The number of frames is bigger than expected");
		
		pState->sectionCount = blockCount;
	}
	
	printf("Section Count: %u\n", pState->sectionCount);
	
	for (int i = 0; i < pState->channelCount; i++)
	{
		UINT offset = 0;
		
		for (int j = 0; j < pState->sectionCount; j++)
		{
			BYTE* pBuffer = &pState->channelStream[i][offset];
			UINT size = blockSize[j] > 0 ? blockSize[j] : pState->channelSize;
			UINT index = j + i * pState->sectionCount;
			pState->sectionStream[pState->chunkCount] = CreateChunk(pBuffer, size, pState->chunkCount, index, i, j);
			offset += size;
			pState->chunkCount++;
		}
	}
	
	for (int i = 0; i < pState->chunkCount; i++)
		for (int j = 0; j < pState->chunkCount; j++)
			FindDuplicateChunk(pState, pState->sectionStream[i], pState->sectionStream[j]);
	
	for (int i = 0; i < pState->chunkCount; i++)
	{
		TChunkSection* pChunk = pState->sectionStream[i];
		
		if (!pChunk->reference)
			CompressChunk(pChunk);		
	}
	
	for (int i = 0; i < pState->chunkCount; i++)
		for (int j = 0; j < pState->chunkCount; j++)
			FindDuplicateChunk(pState, pState->sectionStream[i], pState->sectionStream[j]);
			
	for (int i = 0; i < pState->chunkCount; i++)
	{
		TChunkSection* pChunk = pState->sectionStream[i];
		
		if (!pChunk->reference)
			pState->effectiveSize += pChunk->size;
	}
	
	printf("Effective Size: %u Bytes\n", pState->effectiveSize);
}

// Split each channel to individual byte stream before processing them further
// TODO: Add the SAPR optimisations patches from RMT
void SplitStreams(TSapSplitState* pState)
{
	for (int i = 0; i < pState->channelCount; i++)
		pState->channelStream[i] = CreateStream(pState->fileBuffer, pState->fileSize, pState->channelCount,
		pState->channelSize, i);
	
	// Process optimisations here...
	for (int i = 0; i < pState->channelSize; i++)
	{
		// Apply desired optimisations to the buffered bytes
		switch (pState->optimisationMode)
		{
		case AUDC:
			OptimiseAudc(pState, i);
			break;
	
		case AUDCTL:
			OptimiseAudctl(pState, i);
			break;

		case AUDF:
			OptimiseAudf(pState, i);
			break;

		case AUDC_AUDF:
			OptimiseAudc(pState, i);
			OptimiseAudf(pState, i);
			break;

		case AUDCTL_AUDC:
			OptimiseAudc(pState, i);
			OptimiseAudctl(pState, i);
			break;

		case AUDCTL_AUDF:
			OptimiseAudctl(pState, i);
			OptimiseAudf(pState, i);
			break;

		case ALL_OPTIMISATIONS:
			OptimiseAudc(pState, i);
			OptimiseAudctl(pState, i);
			OptimiseAudf(pState, i);
			break;
		}
	}
}

// Split channel streams into individual chunks, and merge duplicated sections in the process
void SplitAsChunks(TSapSplitState* pState)
{
	// Initialise to the highest possible value in order to make the first iteration become best by default
	UINT iteration = 0;
	UINT dots = 2;
	UINT bestSize = UINT_MAX;
	UINT bestCount = UINT_MAX;
	UINT bestSection = UINT_MAX;
	UINT bestIteration = UINT_MAX;
	
	UINT offset, remainder;
	
	TOptimisationMode bestOptimisation = NO_OPTIMISATION;
	//TCompressionMode bestCompression = ZX2;	//NO_COMPRESSION;
	
	printf("Bruteforcing optimal chunks pattern, it may take some time...\n\n");
//	
	// Split each channels with the optimisation patch needed for this iteration
	for (pState->optimisationMode = NO_OPTIMISATION; pState->optimisationMode <= ALL_OPTIMISATIONS; pState->optimisationMode++)
	{
		printf("Running optimisation pattern %i...\n[ ", pState->optimisationMode);
		fflush(stdout);
		SplitStreams(pState);
	
		// Process every possible section count and chunk size using the channel streams set up above
		for (pState->sectionCount = MIN_SECTION_COUNT; pState->sectionCount < MAX_SECTION_COUNT; pState->sectionCount++)
		{
			// Initialise the variables for each iteration
			pState->effectiveSize = 0;
			pState->effectiveCount = 0;
			pState->chunkCount = 0;
			pState->chunkSize = pState->channelSize / pState->sectionCount;
			remainder = pState->channelSize % pState->sectionCount;
			
			//if (remainder)
			//	continue;
			
			offset = 0;
			
			// Reject anything below the minimal Chunk Size defined
			//if (pState->chunkSize < MIN_CHUNK_SIZE)
			//	continue;
			
			// Reject anything above the maximal Chunk Count defined
			//if ((pState->channelCount * pState->sectionCount) > MAX_CHUNK_COUNT)
			//	continue;
			
			// Phase 1: Create and assign each chunk to its own stream section
			for (int i = 0; i < pState->channelCount; i++)
				for (int j = 0; j < pState->sectionCount; j++)
				{
					BYTE* pBuffer = &pState->channelStream[i][j * pState->chunkSize];
					UINT size = pState->chunkSize + ((j + 1 == pState->sectionCount) ? remainder : 0);
					UINT index = j + i * pState->sectionCount;
					pState->sectionStream[pState->chunkCount++] = CreateChunk(pBuffer, size, offset, index, i, j);
					//offset += size;
					offset++;
				}
			
			// Phase 2: Find and merge duplicated chunk entries
			for (int i = 0; i < pState->chunkCount; i++)
				for (int j = 0; j < pState->chunkCount; j++)
					FindDuplicateChunk(pState, pState->sectionStream[i], pState->sectionStream[j]);
			
			offset = 0;
			
			// Phase 3: Calculate the effective compressed data size by skipping duplicated entries
			for (int i = 0; i < pState->chunkCount; i++)
			{
				TChunkSection* pChunk = pState->sectionStream[i];
				
				if (pChunk->reference)
					continue;
				
				if (pState->compressionMode == ZX2)
					CompressChunk(pChunk);
				
				pState->effectiveSize += pChunk->size;
				pState->effectiveCount++;
				pChunk->offset = offset;
				//offset += pChunk->size;
				offset++;
			
				// Temporary compressed data is no longer needed for this iteration
				// FIXME: add a proper method to handle that stuff
				if (pState->compressionMode == ZX2)
					free(pChunk->buffer);
			}
			
			// Reject anything above the maximal Effective Count defined
			//if (pState->effectiveCount > MAX_EFFECTIVE_COUNT)
			//	continue;
			
			UINT chunkTable = pState->effectiveCount * 2;
			UINT chunkIndex = pState->channelCount * 2;
			UINT sectionTable = (pState->sectionCount + 2) * pState->channelCount;
			
			pState->effectiveSize += chunkTable + chunkIndex + sectionTable;
		
			// Phase 4: Update the best iteration score
			// TODO: Process that in 2 phases: once for the lowest effectiveSize, and once for the lowest number of chunks
			// The best compromise for both smallest size and lowest chunks count will be the the new best score
			if (pState->effectiveSize <= bestSize && pState->effectiveCount <= MAX_EFFECTIVE_COUNT) // && count < bestCount)
			{
				bestSize = pState->effectiveSize;
				bestSection = pState->sectionCount;
				bestCount = pState->effectiveCount;
				bestOptimisation = pState->optimisationMode;
				//bestCompression = pState->compressionMode;
				bestIteration = iteration;
			}
			
			// Phase 5: Delete all chunks created for this iteration before processing the next one
			DeleteAllChunks(pState);
			
			// Update the progress bar display while bruteforcing each iteration
			if ((++iteration * 256 / MAX_SECTION_COUNT > dots))
			{
				printf(".");
				fflush(stdout);
				dots += 4;
			}
		}
	
		// Phase 6: Delete all streams created for this iteration before processing the next one
		DeleteAllStreams(pState);
		printf(" ] ok\n\n");
		printf("Current best score held by iteration %i:\n"
		"effectiveSize %i, effectiveCount %i, sectionCount %i, optimisation %i\n\n",
		bestIteration, bestSize, bestCount, bestSection, bestOptimisation);
		fflush(stdout);
	}
//
	
	printf("Finished bruteforcing, the output will match the best iteration\n\n");
	fflush(stdout);
//	
	// Update the variables for the best iteration score to actually output
	pState->optimisationMode = bestOptimisation;
	//pState->compressionMode = bestCompression;
	pState->sectionCount = bestSection;
	pState->effectiveSize = 0;
	pState->effectiveCount = 0;
	pState->chunkCount = 0;
	pState->chunkSize = pState->channelSize / pState->sectionCount;
	remainder = pState->channelSize % pState->sectionCount;
//

/*
	pState->optimisationMode = 1;
	pState->sectionCount = 113;
	pState->effectiveSize = 0;
	pState->effectiveCount = 0;
	pState->chunkCount = 0;
	pState->chunkSize = pState->channelSize / pState->sectionCount;
	remainder = pState->channelSize % pState->sectionCount;
*/
	
	offset = 0;
	
	// Split the streams for the last time using the optimal parameters
	SplitStreams(pState);
	
	// Phase 1: Create and assign each chunk to its own stream section
	for (int i = 0; i < pState->channelCount; i++)
		for (int j = 0; j < pState->sectionCount; j++)
		{
			BYTE* pBuffer = &pState->channelStream[i][j * pState->chunkSize];
			UINT size = pState->chunkSize + ((j + 1 == pState->sectionCount) ? remainder : 0);
			UINT index = j + i * pState->sectionCount;
			pState->sectionStream[pState->chunkCount++] = CreateChunk(pBuffer, size, offset, index, i, j);
			offset++;
		}

	// Phase 2: Find and merge duplicated chunk entries
	for (int i = 0; i < pState->chunkCount; i++)
		for (int j = 0; j < pState->chunkCount; j++)
			FindDuplicateChunk(pState, pState->sectionStream[i], pState->sectionStream[j]);

/*	
	offset = 0;

	for (int i = 0; i < pState->chunkCount; i++)
	{
		TChunkSection* pChunk = pState->sectionStream[i];
		
		if (pChunk->reference)
		{
			pChunk->offset = pChunk->reference->offset;
			pChunk->reference = NULL;
			continue;
		}
		
		pChunk->reference = NULL;
		pChunk->offset = offset;
		offset++;
	}
	
	for (int i = 0; i < offset; i++)
	{
		for (int j = 0; j < pState->chunkCount; j++)
		{
			TChunkSection* pChunkFrom = pState->sectionStream[j];
			
			if (pChunkFrom->offset != i)
				continue;
			
			for (int k = j + 1; k < pState->chunkCount; k++)
			{
				TChunkSection* pChunkTo = pState->sectionStream[k];
				
				if (pChunkTo->offset != i)
					break;
				
				pChunkFrom->size += pChunkTo->size;
				pChunkTo->size = 0;
			}
		}
	}
	
	for (int i = 0; i < pState->chunkCount; i++)
		for (int j = 0; j < pState->chunkCount; j++)
			FindDuplicateChunk(pState, pState->sectionStream[i], pState->sectionStream[j]);
*/	
	
	offset = 0;

	for (int i = 0; i < pState->chunkCount; i++)
	{
		TChunkSection* pChunk = pState->sectionStream[i];
		
		if (pChunk->reference)
		{
			pChunk->offset = pChunk->reference->offset;
		}
		
		else
		{
			pChunk->offset = offset;
			offset++;
		}
	}
	
	// AAAAAAAAAAAAAAA
	TChunkSection* pChunkChain = NULL;
	
	for (int i = pState->chunkCount - 1; i >= 0; i--)
	{
		TChunkSection* pChunk = pState->sectionStream[i];

		pChunk->linked = pChunkChain;

		if (pChunk->reference)
			pChunk = NULL;
		
		pChunkChain = pChunk;
	}

	//offset = 0;
	
	// Phase 3: Calculate the effective compressed data size then write Chunk files, skipping duplicated entries
	for (int i = 0; i < pState->chunkCount; i++)
	{
		TChunkSection* pChunk = pState->sectionStream[i];

		// If a reference already exists, WriteChunk will handle the rest
		if (pChunk->reference)
		{
			WriteChunk(pState, pChunk);
			continue;
		}
		
		if (pState->compressionMode == ZX2)
			CompressChunk(pChunk);
		
		//pChunk->offset = offset;
		//offset++;
		
		WriteChunk(pState, pChunk);
		
		if (pState->compressionMode == ZX2)
			free(pChunk->buffer);
	}
	
	UINT chunkTable = pState->effectiveCount * 2;
	UINT chunkIndex = pState->channelCount * 2;
	UINT sectionTable = (pState->sectionCount + 2) * pState->channelCount;
			
	pState->effectiveSize += chunkTable + chunkIndex + sectionTable;
	
	printf("\nWrote %i unique chunks, merged %i duplicated chunks, for a total of %i chunks\n",
	pState->effectiveCount, pState->chunkCount - pState->effectiveCount, pState->chunkCount);
	printf("Effective size: %i bytes, reduced from %i bytes (%0.02f%% of original size)\n",
	pState->effectiveSize, pState->fileSize, pState->effectiveSize * 100.0 / pState->fileSize);
	printf("Optimisation %i was found to be the most efficient\n", pState->optimisationMode);
	printf("A total of %i iterations were processed\n\n", iteration);

//	
	// Phase 4: Create a lookup table to reconstruct the original data using Chunks
	printf("Creating the lookup table for reconstructing the original data using Chunks...\n\n");

	printf("ChunkIndexLSB:\n\t.byte ");
	
	for (int i = 0, j = 0; i < pState->chunkCount; i++)
	{
		TChunkSection* pChunk = pState->sectionStream[i];
		
		if (pChunk->reference)
			continue;
		
		printf("<Chunk_%X_%02X%s", pChunk->channel, pChunk->section, (++j == pState->effectiveCount) ? "\n" : ", ");
	}
	
	printf("ChunkIndexMSB:\n\t.byte ");
	
	for (int i = 0, j = 0; i < pState->chunkCount; i++)
	{
		TChunkSection* pChunk = pState->sectionStream[i];
		
		if (pChunk->reference)
			continue;
		
		printf(">Chunk_%X_%02X%s", pChunk->channel, pChunk->section, (++j == pState->effectiveCount) ? "\n" : ", ");
	}
	
	printf("ChunkSection:\n\t.word ");
	
	for (int i = 0; i < pState->channelCount; i++)
	{
		printf("Section_%i%s", i, (i == pState->channelCount - 1) ? "\n" : ", ");
	}
	
	for (int i = 0; i < pState->channelCount; i++)
	{
		printf("Section_%i:\n\t.byte ", i);
		
		for (int j = 0; j < pState->chunkCount; j++)
		{
			TChunkSection* pChunk = pState->sectionStream[j];
			
			if (pChunk->channel != i)
				continue;
			
			UINT offset = pChunk->reference ? pChunk->reference->offset : pChunk->offset;
			UINT section = pChunk->section;
			
			printf("$%02X%s", offset, (section == pState->sectionCount - 1) ? "\n" : ", ");
		}
		
		// Append the Bytecode for End of Section, and Loop Point, by default returning to the first position
		printf("\tGOTOCHUNK 0\n");
	}
	
	for (int i = 0, j = 0; i < pState->chunkCount; i++)
	{
		TChunkSection* pChunk = pState->sectionStream[i];
		
		if (pChunk->reference)
			continue;
		
		printf("Chunk_%X_%02X:\n\t", pChunk->channel, pChunk->section);
		printf("ins \"%s.%X_%02X\"\n", pState->outputName, pChunk->channel, pChunk->section);
	}
//
}

// Split channel streams from input file and save them as individual files
void SplitAsChannels(TSapSplitState* pState)
{
	UINT bestSize = UINT_MAX;
	UINT bestOptimisation = NO_OPTIMISATION;
	
	for (pState->optimisationMode = NO_OPTIMISATION; pState->optimisationMode <= ALL_OPTIMISATIONS; pState->optimisationMode++)
	{
		UINT size = 0;
		pState->chunkCount = 0;
		
		SplitStreams(pState);
		
		for (int i = 0; i < pState->channelCount; i++)
			pState->sectionStream[i] = CreateChunk(pState->channelStream[i], pState->channelSize, pState->chunkCount++, i, i, 0);
		
		for (int i = 0; i < pState->channelCount; i++)
			for (int j = 0; j < pState->channelCount; j++)
				FindDuplicateChunk(pState, pState->sectionStream[i], pState->sectionStream[j]);
		
		for (int i = 0; i < pState->channelCount; i++)
			CompressChunk(pState->sectionStream[i]);
		
		for (int i = 0; i < pState->channelCount; i++)
			for (int j = 0; j < pState->channelCount; j++)
				FindDuplicateChunk(pState, pState->sectionStream[i], pState->sectionStream[j]);
		
		for (int i = 0; i < pState->channelCount; i++)
		{
			TChunkSection* pChunk = pState->sectionStream[i];
			
			if (pChunk->reference)
				continue;
			
			size += pChunk->size;
		}
		
		if (size < bestSize)
		{
			bestSize = size;
			bestOptimisation = pState->optimisationMode;	
		}
		
		DeleteAllChunks(pState);
		DeleteAllStreams(pState);
	}
	
	pState->chunkCount = 0;
	pState->optimisationMode = bestOptimisation;
	SplitStreams(pState);
	
	for (int i = 0; i < pState->channelCount; i++)
		pState->sectionStream[i] = CreateChunk(pState->channelStream[i], pState->channelSize, pState->chunkCount++, i, i, 0);
	
	for (int i = 0; i < pState->channelCount; i++)
		for (int j = 0; j < pState->channelCount; j++)
			FindDuplicateChunk(pState, pState->sectionStream[i], pState->sectionStream[j]);
	
	for (int i = 0; i < pState->channelCount; i++)
		CompressChunk(pState->sectionStream[i]);
	
	for (int i = 0; i < pState->channelCount; i++)
		for (int j = 0; j < pState->channelCount; j++)
			FindDuplicateChunk(pState, pState->sectionStream[i], pState->sectionStream[j]);
	
	for (int i = 0; i < pState->channelCount; i++)
		WriteChunk(pState, pState->sectionStream[i]);
	
	printf("\nWrote %i unique chunks, merged %i duplicated chunks, for a total of %i chunks\n",
	pState->effectiveCount, pState->chunkCount - pState->effectiveCount, pState->chunkCount);
	printf("Effective size: %i bytes, reduced from %i bytes (%0.02f%% of original size)\n",
	pState->effectiveSize, pState->fileSize, pState->effectiveSize * 100.0 / pState->fileSize);
	printf("Optimisation %i was found to be the most efficient\n", pState->optimisationMode);
}

void ProcessStreams(TSapSplitState* pState)
{	
	switch (pState->optionMode)
	{		
	case ANALYSE:
		AnalyseStreams(pState);
		return;
	
	case SPLIT:
		SplitAsChannels(pState);
		return;
		
	case MERGE:
		SplitAsChunks(pState);
		return;

	default:
		Quit(FAILURE, "Missing argument: [-m] [option]");
	}
}

void FreeMemory(TSapSplitState* pState)
{
	// We no longer need the file buffer at this point
	if (pState->fileBuffer)
	{
		free(pState->fileBuffer);
		pState->fileBuffer = NULL;
	}

	// Delete all leftover streams
	if (pState->channelStream)
	{
		DeleteAllStreams(pState);
		free(pState->channelStream);
		pState->channelStream = NULL;
	}

	// Delete all leftover chunks
	if (pState->sectionStream)
	{
		DeleteAllChunks(pState);
		free(pState->sectionStream);
		pState->sectionStream = NULL;
	}

}

void OptimiseAudc(TSapSplitState* pState, UINT offset)
{
	for (int i = 1; i < POKEY; i += 2)
	{
		BYTE* audc = &pState->channelStream[i][offset];

		// RMT will handle both the Proper Volume Only output, and the SAP-R dump patch for the Two-Tone Filter
		if (*audc < 0xF0)
		{
			// No volume, ignore distortion bits
			if (!(*audc & 0x0F))
				*audc = 0;
			
			// No noise, ignore noise type bit
			else if (*audc & 0x20)
				*audc &= 0xBF;
		}
	}
}

void OptimiseAudctl(TSapSplitState* pState, UINT offset)
{
	BYTE* audc1 = &pState->channelStream[1][offset];
	BYTE* audc2 = &pState->channelStream[3][offset];
	BYTE* audc3 = &pState->channelStream[5][offset];
	BYTE* audc4 = &pState->channelStream[7][offset];
	BYTE* audctl = &pState->channelStream[8][offset];
	
	// CH1 is mute, disable High Pass Filter in CH1+3
	if (!(*audc1 & 0x0F))
		*audctl &= 0xFB;

	// CH1 is mute and Join1+2 is not set, disable 1.79mhz clock in CH1
	if (!(*audc1 & 0x0F) && !(*audctl & 0x10))
		*audctl &= 0xBF;

	// Both CH1 and CH2 are mute, disable 16-bit mode
	if (!(*audc1 & 0x0F) && !(*audc2 & 0x0F))
		*audctl &= 0xAF;

	// CH2 is mute, disable High Pass Filter in CH2+4
	if (!(*audc2 & 0x0F))
		*audctl &= 0xFD;

	// CH3 is mute and Join3+4 is not set, disable 1.79mhz clock in CH3, if Filter in CH1+3 is also disabled
	if (!(*audc3 & 0x0F) && !(*audctl & 0x08) && !(*audctl & 0x04))
		*audctl &= 0xDF;

	// Both CH3 and CH4 are mute, disable 16-bit mode
	if (!(*audc3 & 0x0F) && !(*audc4 & 0x0F))
		*audctl &= 0xF7;
}

void OptimiseAudf(TSapSplitState* pState, UINT offset)
{
	BYTE* audctl = &pState->channelStream[8][offset];

	for (int i = 1; i < POKEY; i += 2)
	{
		BYTE* audc = &pState->channelStream[i][offset];
		BYTE* audf = &pState->channelStream[i - 1][offset];

		// Check if there is no volume, and if the AUDCTL actually needs the AUDF
		if (*audc & 0x0F)
			continue;
		
		// This is literally a case by case situation, this is painful
		switch (i)
		{
		case 1:
			if (!(*audctl & 0x04 || *audctl & 0x10 || *audctl & 0x40))
				*audf = 0;
			continue;

		case 3:
			if (!(*audctl & 0x02 || *audctl & 0x10 || ((*audc & 0x10) && (*audc < 0xF0))))
				*audf = 0;
			continue;

		case 5:
			if (!(*audctl & 0x04 || *audctl & 0x08 || *audctl & 0x20))
				*audf = 0;
			continue;

		case 7:
			if (!(*audctl & 0x02 || *audctl & 0x08))
				*audf = 0;
			continue;
		}
	}
}

int main(int argc, char** argv)
{
	// Just so things look less cramped right off the bat
	printf("\n");
	
	// If the program was executed with no argument, display the help screen by default
	if (argc <= 1)
		Quit(HELP_SCREEN, argv[0]);

	// Create and initialise the program variables to be used
	TSapSplitState state;
	memset(&state, 0, sizeof(TSapSplitState));

	// Parse the command line arguments
	ProcessArguments(&state, argc, argv);
	
	// Load the input file from which the channel streams will be filled
	LoadInputFile(&state);
	
	// Run the procedure using all the necessary parameters
	ProcessStreams(&state);
	
	// Clear all the allocated memory
	FreeMemory(&state);
	
	// Finished without error
	Quit(SUCCESSFUL, NULL);
}

void CompressChunk(TChunkSection* pChunk)
{
	if (!pChunk)
		Quit(FAILURE, NULL);
	
	// Already processed, nothing to do here
	if (pChunk->reference)
		return;
	
	zx02_state* pZx02State = calloc(sizeof(zx02_state), 1);
	
	if (!pZx02State)
		Quit(NOT_ENOUGH_MEMORY, NULL);
	
	pZx02State->input_data = pChunk->buffer;
	pZx02State->input_size = pChunk->size;
	
	pZx02State->initial_offset = 1;
	pZx02State->zx2_mode = 1;
	pZx02State->offset_limit = MAX_OFFSET_ZX202;
	
	UINT output_size;
	UINT delta;

	// Generate compressed data from the chunk parameters
	pChunk->buffer = compress(optimize(pZx02State), pZx02State, &output_size, &delta);
	
	// Update the chunk size to match the compressed data size
	pChunk->size = output_size;
	
	// Flush most of the allocated memory (hopefully...)
	FlushBlocks(pZx02State);

/*	
	int MAX_OFFSET_ZX2 = 255;
	int skip = 0;
	int backwards_mode = FALSE;
	int last_offset = INITIAL_OFFSET;
	int min_length = 2;
	int limited_length = FALSE;
	int output_size;
	int delta;

	// Generate compressed data from the chunk parameters
	pChunk->buffer = compress(optimize(pChunk->buffer, pChunk->size, skip, MAX_OFFSET_ZX2, last_offset, min_length),
	pChunk->buffer, pChunk->size, skip, backwards_mode, last_offset, min_length, limited_length, &output_size, &delta);
	
	// Update the chunk size to match the compressed data size
	pChunk->size = output_size;
	
	// Flush most of the allocated memory (hopefully...)
	FlushBlocks();
*/	
	//Quit(FAILURE, "This is a test, I need to find what the fuck was done with the memory heap...");
}

