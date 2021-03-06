#include <sstream>
#include <set>
#include <iterator>
#include <cfloat>

#include "Grid.h"
#include "vtkCPDataDescription.h"
#include "vtkCPInputDataDescription.h"
#include "vtkCPProcessor.h"
#include "vtkCPPythonScriptPipeline.h"
#include "vtkMath.h"
#include "vtkUnstructuredGrid.h"
#include "vtkSmartPointer.h"

namespace
{
vtkCPProcessor* g_coprocessor;             // catalyst coprocessor
vtkCPDataDescription* g_coprocessorData;   // sinput, sinput3d
bool g_isTimeDataSet;                      // is time data set?
Grid<CUBE_SPHERE>* g_grid;                 // 2d,3d cubed-spheres
};

///////////////////////////////////////////////////////////////////////////

// Initializes the Catalyst Coprocessor
// WARNING: Make sure you pass a zero terminated string
extern "C" void se_coprocessorinitializewithpython_(const char* pythonScriptName)
{
  vtkGenericWarningMacro("CALLED FUNCTION.");
  if (!g_coprocessor)
    {
    vtkGenericWarningMacro("INIT COPROCESSOR.");
    g_coprocessor = vtkCPProcessor::New();
    g_coprocessor->Initialize();
    // python pipeline
    vtkSmartPointer<vtkCPPythonScriptPipeline> pipeline =
      vtkSmartPointer<vtkCPPythonScriptPipeline>::New();
    pipeline->Initialize(pythonScriptName);
    g_coprocessor->AddPipeline(pipeline);
    }
  if (!g_coprocessorData)
    {
    vtkGenericWarningMacro("INIT DATA.");
    g_coprocessorData = vtkCPDataDescription::New();
    g_coprocessorData->AddInput("input");
    g_coprocessorData->AddInput("input3D");
    }
}

// Creates grids for 2d and 3d cubed-spheres
extern "C" void se_create_grid_(
  int* ne, int* np, int* nlon, double* lonRad, int* nlat, double* latRad,
  int* nlev, double* lev, int* nCells2d, int* maxNcols, int* mpiRank)
{
  if (!g_coprocessorData)
    {
    vtkGenericWarningMacro("Unable to access CoProcessorData.");
    return;
    }  

  g_grid = new Grid<CUBE_SPHERE>();
  g_grid->SetMpiRank(*mpiRank);
  g_grid->SetChunkCapacity(*maxNcols);
  int points = *ne * *np + 1;
  g_grid->SetNCells2d(points * points * 6);
  g_grid->SetCubeGridPoints(*ne, *np, *nlon, lonRad, *nlat, latRad);
  g_grid->SetLev(*nlev, lev);
  g_grid->Create();
  if (! Grid<CUBE_SPHERE>::SetToCoprocessor(g_coprocessorData, "input", g_grid->GetGrid2d()) ||
      ! Grid<CUBE_SPHERE>::SetToCoprocessor(g_coprocessorData, "input3D", g_grid->GetGrid3d()))
    {
    vtkGenericWarningMacro(<< "No input data description");
    delete g_grid;
    g_grid = NULL;
    }
}

// for timestep 0: creates the points and cells for the grids.
// for all timesteps: copies data from the simulation to Catalyst.
extern "C" void se_add_chunk_(
  int* nstep, int* chunkSize,
  double* lonRad, double* latRad,
  double* psScalar, double *tScalar, double* uScalar, double* vScalar)
{
  if (*nstep == 0)
    {
    std::ostringstream ostr;
    ostr << "se_add_chunk: " << *chunkSize << std::endl;
    std::cerr << ostr.str();
    for (int i = 0; i < *chunkSize; ++i)
      {
      if (g_grid)
        {
        g_grid->AddPointsAndCells(lonRad[i], latRad[i]);
        }
      }
    }
  if (g_grid)
    {
    g_grid->SetAttributeValue(*chunkSize, lonRad, latRad,
                               psScalar, tScalar, uScalar, vScalar);
    }
}

// Deletes global data
extern "C" void se_finalize_()
{
  if (g_grid)
    {
    delete g_grid;
    }
}

// Deletes the Catalyt Coprocessor and data
extern "C" void se_coprocessorfinalize_()
{
  if (g_coprocessor)
    {
    g_coprocessor->Delete();
    g_coprocessor = NULL;
    }
  if (g_coprocessorData)
    {
    g_coprocessorData->Delete();
    g_coprocessorData = NULL;
    }
}

// Checks if Catalyst needs to coprocess data
extern "C" int se_requestdatadescription_(int* timeStep, double* time)
{
  if(!g_coprocessor)
    {
    vtkGenericWarningMacro("Coprocessor not initialized.");
    return 0;
    }
  if(!g_coprocessorData)
    {
    vtkGenericWarningMacro("Data is not initialized.");
    return 0;
    }
  
  vtkIdType tStep = *timeStep;
  g_coprocessorData->SetTimeData(*time, tStep);
  if(g_coprocessor->RequestDataDescription(g_coprocessorData))
    {
    g_isTimeDataSet = true;
    return 1;
    }
  else
    {
    g_isTimeDataSet = false;
    return 0;
    }
}

// Checks if the grids need to be created
extern "C" int se_needtocreategrid_()
{
  if(!g_isTimeDataSet)
    {
    vtkGenericWarningMacro("Time data not set.");
    return 0;
    }

  // assume that the grid is not changing so that we only build it
  // the first time, otherwise we clear out the field data
  vtkCPInputDataDescription* idd = 
    g_coprocessorData->GetInputDescriptionByName("input");
  return (idd == NULL || idd->GetGrid() == NULL);
}

// calls the coprocessor
extern "C" void se_coprocess_()
{
  if(!g_isTimeDataSet)
    {
    vtkGenericWarningMacro("Time data not set.");
    }
  else
    {
    g_coprocessor->CoProcess(g_coprocessorData);
    }
  // Reset time data.
  g_isTimeDataSet = false;
}
