// SAPSPLIT v0.1 by VinsCool

// Typical POKEY channels layout: 4 AUDF, 4 AUDC, 1 AUDCTL
// SKCTL is currently not supported with the SAP-R format
// Multiply the numbers based on the POKEY configuration
#define POKEY			((4 * 2) + 1)
#define MONO_POKEY		(POKEY * 1)
#define STEREO_POKEY		(POKEY * 2)
#define TRIPLE_POKEY		(POKEY * 3)
#define QUAD_POKEY		(POKEY * 4)
#define MIN_CHUNK_SIZE		256
#define MAX_CHUNK_SIZE		UINT_MAX
#define MIN_SECTION_COUNT	1
#define MAX_SECTION_COUNT	256
#define MIN_STREAM_COUNT	MONO_POKEY
#define MAX_STREAM_COUNT	QUAD_POKEY
#define MIN_CHUNK_COUNT		1
#define MAX_CHUNK_COUNT		(MAX_SECTION_COUNT * MAX_STREAM_COUNT)
#define MAX_EFFECTIVE_COUNT	(MAX_SECTION_COUNT-1)//(MAX_SECTION_COUNT / 2)

typedef unsigned char BYTE;
typedef unsigned int UINT;

typedef enum statusCode_t
{
	FAILURE = -1,
	SUCCESSFUL,
	INPUT_ERROR,
	OUTPUT_ERROR,
	ARGUMENT_ERROR,
	PARAMETER_ERROR,
	HELP_SCREEN,
	INVALID_DATA,
	NOT_ENOUGH_MEMORY
} TStatusCode;

typedef enum optionMode_t
{
	UNDEFINED = -1,
	SPLIT,
	MERGE,
	CONCATENATE,
	ANALYSE
} TOptionMode;

typedef enum optimisationMode_t
{
	NO_OPTIMISATION = 0,
	AUDC,
	AUDCTL,
	AUDF,
	AUDC_AUDF,
	AUDCTL_AUDC,
	AUDCTL_AUDF,
	ALL_OPTIMISATIONS
} TOptimisationMode;

typedef enum compressionMode_t
{
	NO_COMPRESSION = 0,
	ZX2
} TCompressionMode;

typedef struct chunkSection_t
{
	struct chunkSection_t* reference;
	struct chunkSection_t* linked;
	BYTE* buffer;
	UINT size;
	UINT offset;
	UINT index;
	UINT channel;
	UINT section;
	//bool isDuplicate;
} TChunkSection;

typedef struct sapSplitState_t
{
	TChunkSection** sectionStream;
	BYTE** channelStream;
	BYTE* fileBuffer;
	char* inputName;
	char* outputName;
	char* chunkStream;
	UINT fileSize;
	UINT channelCount;
	UINT channelSize;
	UINT sectionCount;
	UINT chunkCount;
	UINT chunkSize;
	UINT effectiveSize;
	UINT effectiveCount;
	TOptionMode optionMode;
	TOptimisationMode optimisationMode;
	TCompressionMode compressionMode;
} TSapSplitState;

int main(int argc, char** argv);

void ProcessArguments(TSapSplitState* pState, int argc, char** argv);
void Quit(TStatusCode statusCode, const char* argument);

void FreeMemory(TSapSplitState* pState);
void LoadInputFile(TSapSplitState* pState);
void AnalyseStreams(TSapSplitState* pState);
void SplitStreams(TSapSplitState* pState);
void SplitAsChunks(TSapSplitState* pState);
void SplitAsChannels(TSapSplitState* pState);
void ProcessStreams(TSapSplitState* pState);

void FindDuplicateChunk(TSapSplitState* pState, TChunkSection* pChunkFrom, TChunkSection* pChunkTo);
void WriteChunk(TSapSplitState* pState, TChunkSection* pChunk);
TChunkSection* DeleteChunk(TChunkSection* pChunk);
//TChunkSection* CreateChunk(BYTE* buffer, int size, int channel, int section);
TChunkSection* CreateChunk(BYTE* buffer, UINT size, UINT offset, UINT index, UINT channel, UINT section);
void DeleteAllChunks(TSapSplitState* pState);
void CompressChunk(TChunkSection* pChunk);

BYTE* DeleteStream(BYTE* pStream);
void DeleteAllStreams(TSapSplitState* pState);

void OptimiseAudc(TSapSplitState* pState, UINT offset);
void OptimiseAudctl(TSapSplitState* pState, UINT offset);
void OptimiseAudf(TSapSplitState* pState, UINT offset);

