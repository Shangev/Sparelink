// Vehicle Data Service
// This fetches car makes, models, and years from the backend
// Currently using local data, but structured for easy backend integration

export interface CarMake {
  id: string;
  name: string;
  logo?: string;
}

export interface CarModel {
  id: string;
  name: string;
  makeId: string;
}

// Car Makes Data (would come from backend API)
export const CAR_MAKES: CarMake[] = [
  { id: '1', name: 'Toyota' },
  { id: '2', name: 'Volkswagen (VW)' },
  { id: '3', name: 'Ford' },
  { id: '4', name: 'Mercedes-Benz' },
  { id: '5', name: 'BMW' },
  { id: '6', name: 'Audi' },
  { id: '7', name: 'Honda' },
  { id: '8', name: 'Nissan' },
  { id: '9', name: 'Hyundai' },
  { id: '10', name: 'Kia' },
  { id: '11', name: 'Mazda' },
  { id: '12', name: 'Chevrolet' },
  { id: '13', name: 'Jeep' },
  { id: '14', name: 'Renault' },
  { id: '15', name: 'Peugeot' },
  { id: '16', name: 'Opel' },
  { id: '17', name: 'Subaru' },
  { id: '18', name: 'Volvo' },
  { id: '19', name: 'Lexus' },
  { id: '20', name: 'Mitsubishi' },
].sort((a, b) => a.name.localeCompare(b.name));

// Car Models Data (would come from backend API based on makeId)
export const CAR_MODELS: Record<string, CarModel[]> = {
  '1': [ // Toyota
    { id: '1-1', name: 'Corolla', makeId: '1' },
    { id: '1-2', name: 'Camry', makeId: '1' },
    { id: '1-3', name: 'Hilux', makeId: '1' },
    { id: '1-4', name: 'RAV4', makeId: '1' },
    { id: '1-5', name: 'Land Cruiser', makeId: '1' },
    { id: '1-6', name: 'Prius', makeId: '1' },
    { id: '1-7', name: 'Fortuner', makeId: '1' },
    { id: '1-8', name: 'Yaris', makeId: '1' },
  ],
  '2': [ // VW
    { id: '2-1', name: 'Golf', makeId: '2' },
    { id: '2-2', name: 'Polo', makeId: '2' },
    { id: '2-3', name: 'Tiguan', makeId: '2' },
    { id: '2-4', name: 'Passat', makeId: '2' },
    { id: '2-5', name: 'Jetta', makeId: '2' },
    { id: '2-6', name: 'Amarok', makeId: '2' },
    { id: '2-7', name: 'T-Roc', makeId: '2' },
  ],
  '3': [ // Ford
    { id: '3-1', name: 'Fiesta', makeId: '3' },
    { id: '3-2', name: 'Focus', makeId: '3' },
    { id: '3-3', name: 'Ranger', makeId: '3' },
    { id: '3-4', name: 'Mustang', makeId: '3' },
    { id: '3-5', name: 'EcoSport', makeId: '3' },
    { id: '3-6', name: 'Everest', makeId: '3' },
    { id: '3-7', name: 'F-150', makeId: '3' },
  ],
  '4': [ // Mercedes-Benz
    { id: '4-1', name: 'C-Class', makeId: '4' },
    { id: '4-2', name: 'E-Class', makeId: '4' },
    { id: '4-3', name: 'S-Class', makeId: '4' },
    { id: '4-4', name: 'GLA', makeId: '4' },
    { id: '4-5', name: 'GLC', makeId: '4' },
    { id: '4-6', name: 'GLE', makeId: '4' },
    { id: '4-7', name: 'A-Class', makeId: '4' },
  ],
  '5': [ // BMW
    { id: '5-1', name: '3 Series', makeId: '5' },
    { id: '5-2', name: '5 Series', makeId: '5' },
    { id: '5-3', name: '7 Series', makeId: '5' },
    { id: '5-4', name: 'X3', makeId: '5' },
    { id: '5-5', name: 'X5', makeId: '5' },
    { id: '5-6', name: 'X1', makeId: '5' },
    { id: '5-7', name: '1 Series', makeId: '5' },
  ],
  '6': [ // Audi
    { id: '6-1', name: 'A3', makeId: '6' },
    { id: '6-2', name: 'A4', makeId: '6' },
    { id: '6-3', name: 'A6', makeId: '6' },
    { id: '6-4', name: 'Q3', makeId: '6' },
    { id: '6-5', name: 'Q5', makeId: '6' },
    { id: '6-6', name: 'Q7', makeId: '6' },
    { id: '6-7', name: 'TT', makeId: '6' },
  ],
  '7': [ // Honda
    { id: '7-1', name: 'Civic', makeId: '7' },
    { id: '7-2', name: 'Accord', makeId: '7' },
    { id: '7-3', name: 'CR-V', makeId: '7' },
    { id: '7-4', name: 'HR-V', makeId: '7' },
    { id: '7-5', name: 'Jazz', makeId: '7' },
    { id: '7-6', name: 'Pilot', makeId: '7' },
  ],
  // Add more makes as needed
};

// Generate years from 1980 to current year + 1
export const getCarYears = (): string[] => {
  const currentYear = new Date().getFullYear();
  const years: string[] = [];
  for (let year = currentYear + 1; year >= 1980; year--) {
    years.push(year.toString());
  }
  return years;
};

// API Functions (for backend integration)
export const fetchCarMakes = async (): Promise<CarMake[]> => {
  // TODO: Replace with actual API call
  // const response = await fetch('https://api.sparelink.com/vehicle/makes');
  // return response.json();
  return Promise.resolve(CAR_MAKES);
};

export const fetchCarModels = async (makeId: string): Promise<CarModel[]> => {
  // TODO: Replace with actual API call
  // const response = await fetch(`https://api.sparelink.com/vehicle/makes/${makeId}/models`);
  // return response.json();
  return Promise.resolve(CAR_MODELS[makeId] || []);
};

export const fetchCarYears = async (): Promise<string[]> => {
  // TODO: Replace with actual API call if years are dynamic
  return Promise.resolve(getCarYears());
};
