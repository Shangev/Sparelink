import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Image,
  SafeAreaView,
} from 'react-native';
import { CameraView, useCameraPermissions, CameraType, FlashMode } from 'expo-camera';
import * as ImagePicker from 'expo-image-picker';
import { ChevronLeft, Zap, ZapOff, RotateCw, ZoomIn, ZoomOut, Grid3x3, Image as ImageIcon, X as XIcon, Check, Car, Calendar, Send, Hash } from 'lucide-react-native';
import { ScrollView, Dimensions, TextInput } from 'react-native';
import DropdownModal from '../components/DropdownModal';
import { fetchCarMakes, fetchCarModels, fetchCarYears, CarMake, CarModel } from '../services/vehicleData';

const { width } = Dimensions.get('window');

export default function RequestPartFlowMinimal({ navigation }: any) {
  const [currentStep, setCurrentStep] = useState<'camera' | 'preview' | 'details'>('camera');
  const [capturedImages, setCapturedImages] = useState<string[]>([]);
  const [permission, requestPermission] = useCameraPermissions();
  const cameraRef = useRef<CameraView>(null);
  
  // Camera controls
  const [facing, setFacing] = useState<CameraType>('back');
  const [flash, setFlash] = useState<FlashMode>('off');
  const [zoom, setZoom] = useState(0);
  const [showGrid, setShowGrid] = useState(false);
  const [multiPhotoMode, setMultiPhotoMode] = useState(true); // Enable multi-photo by default
  
  // Vehicle details state
  const [selectedMake, setSelectedMake] = useState('');
  const [selectedMakeId, setSelectedMakeId] = useState('');
  const [selectedModel, setSelectedModel] = useState('');
  const [selectedYear, setSelectedYear] = useState('');
  const [vinNumber, setVinNumber] = useState('');
  const [engineNumber, setEngineNumber] = useState('');
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  
  // Dropdown data
  const [carMakes, setCarMakes] = useState<CarMake[]>([]);
  const [carModels, setCarModels] = useState<CarModel[]>([]);
  const [carYears, setCarYears] = useState<string[]>([]);
  
  // Modal visibility
  const [showMakeModal, setShowMakeModal] = useState(false);
  const [showModelModal, setShowModelModal] = useState(false);
  const [showYearModal, setShowYearModal] = useState(false);
  
  // Load data
  useEffect(() => {
    loadVehicleData();
  }, []);
  
  useEffect(() => {
    if (selectedMakeId) {
      loadModels(selectedMakeId);
    }
  }, [selectedMakeId]);
  
  const loadVehicleData = async () => {
    const [makes, years] = await Promise.all([
      fetchCarMakes(),
      fetchCarYears(),
    ]);
    setCarMakes(makes);
    setCarYears(years);
  };
  
  const loadModels = async (makeId: string) => {
    const models = await fetchCarModels(makeId);
    setCarModels(models);
  };
  
  const handleMakeSelect = (makeName: string) => {
    const make = carMakes.find(m => m.name === makeName);
    if (make) {
      setSelectedMake(makeName);
      setSelectedMakeId(make.id);
      setSelectedModel(''); // Reset model when make changes
    }
  };

  const takePicture = async () => {
    if (cameraRef.current) {
      const photo = await cameraRef.current.takePictureAsync();
      if (photo) {
        if (multiPhotoMode) {
          // Add to array of photos
          setCapturedImages([...capturedImages, photo.uri]);
          // Stay on camera to take more
        } else {
          // Single photo mode - go to preview
          setCapturedImages([photo.uri]);
          setCurrentStep('preview');
        }
      }
    }
  };

  const pickFromGallery = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: false,
      quality: 1,
      allowsMultipleSelection: true,
    });
    
    if (!result.canceled) {
      const uris = result.assets.map(asset => asset.uri);
      setCapturedImages([...capturedImages, ...uris]);
    }
  };

  const removePhoto = (index: number) => {
    setCapturedImages(capturedImages.filter((_, i) => i !== index));
  };

  const confirmAllPhotos = () => {
    console.log('All photos confirmed:', capturedImages);
    setCurrentStep('preview');
  };

  const toggleCategory = (category: string) => {
    setSelectedCategories(prev =>
      prev.includes(category) 
        ? prev.filter(c => c !== category) 
        : [...prev, category]
    );
  };

  const submitRequest = () => {
    console.log('Request submitted:', {
      photos: capturedImages,
      make: selectedMake,
      model: selectedModel,
      year: selectedYear,
      vinNumber: vinNumber,
      engineNumber: engineNumber,
      categories: selectedCategories,
    });
    // TODO: Send to backend
    navigation.goBack();
  };

  if (!permission) {
    return <View style={styles.container}><Text>Loading...</Text></View>;
  }

  if (!permission.granted) {
    return (
      <View style={styles.container}>
        <Text style={styles.message}>Camera permission is required</Text>
        <TouchableOpacity onPress={requestPermission} style={styles.button}>
          <Text style={styles.buttonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  // CAMERA VIEW - ENHANCED VERSION
  if (currentStep === 'camera') {
    return (
      <View style={styles.container}>
        <CameraView
          ref={cameraRef}
          style={StyleSheet.absoluteFill}
          facing={facing}
          flash={flash}
          zoom={zoom}
        />
        
        {/* Top Bar */}
          <SafeAreaView style={styles.topBar}>
            <TouchableOpacity onPress={() => navigation.goBack()} style={styles.iconButton}>
              <ChevronLeft size={28} color="#fff" />
            </TouchableOpacity>
            
            <View style={styles.topRightControls}>
              <TouchableOpacity 
                onPress={() => setFlash(flash === 'off' ? 'on' : 'off')} 
                style={styles.iconButton}
              >
                {flash === 'on' ? (
                  <Zap size={28} color="#FFD700" fill="#FFD700" />
                ) : (
                  <ZapOff size={28} color="#fff" />
                )}
              </TouchableOpacity>
              
              <TouchableOpacity 
                onPress={() => setShowGrid(!showGrid)} 
                style={styles.iconButton}
              >
                <Grid3x3 size={28} color={showGrid ? '#FFD700' : '#fff'} />
              </TouchableOpacity>
            </View>
          </SafeAreaView>

          {/* Grid Overlay */}
          {showGrid && (
            <View style={styles.gridOverlay}>
              <View style={styles.gridLine} />
              <View style={[styles.gridLine, styles.gridLineVertical]} />
              <View style={[styles.gridLine, { top: '33.33%' }]} />
              <View style={[styles.gridLine, { top: '66.66%' }]} />
              <View style={[styles.gridLine, styles.gridLineVertical, { left: '33.33%' }]} />
              <View style={[styles.gridLine, styles.gridLineVertical, { left: '66.66%' }]} />
            </View>
          )}

          {/* Right Side Controls */}
          {/* Right Side Controls */}
          <View style={styles.rightControls}>
            <TouchableOpacity 
              onPress={() => setFacing(facing === 'back' ? 'front' : 'back')}
              style={styles.iconButton}
            >
              <RotateCw size={28} color="#fff" />
            </TouchableOpacity>
            
            <TouchableOpacity 
              onPress={pickFromGallery}
              style={styles.iconButton}
            >
              <ImageIcon size={28} color="#fff" />
            </TouchableOpacity>
            
            <TouchableOpacity 
              onPress={() => setZoom(Math.min(zoom + 0.1, 1))}
              style={styles.iconButton}
              disabled={zoom >= 1}
            >
              <ZoomIn size={28} color={zoom >= 1 ? '#666' : '#fff'} />
            </TouchableOpacity>
            
            <TouchableOpacity 
              onPress={() => setZoom(Math.max(zoom - 0.1, 0))}
              style={styles.iconButton}
              disabled={zoom <= 0}
            >
              <ZoomOut size={28} color={zoom <= 0 ? '#666' : '#fff'} />
            </TouchableOpacity>
          </View>

        {/* Photo Thumbnails Strip */}
        {capturedImages.length > 0 && (
          <View style={styles.thumbnailStrip}>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.thumbnailScroll}>
              {capturedImages.map((uri, index) => (
                <View key={index} style={styles.thumbnailContainer}>
                  <Image source={{ uri }} style={styles.thumbnail} />
                  <TouchableOpacity 
                    style={styles.removeThumbnail} 
                    onPress={() => removePhoto(index)}
                  >
                    <XIcon size={16} color="#fff" />
                  </TouchableOpacity>
                </View>
              ))}
            </ScrollView>
            <Text style={styles.photoCount}>{capturedImages.length} photo{capturedImages.length !== 1 ? 's' : ''}</Text>
          </View>
        )}

        {/* Bottom Controls */}
        <View style={styles.bottomBar}>
          {capturedImages.length > 0 && (
            <TouchableOpacity style={styles.doneButton} onPress={confirmAllPhotos}>
              <Check size={24} color="#fff" />
              <Text style={styles.doneButtonText}>Done ({capturedImages.length})</Text>
            </TouchableOpacity>
          )}
          <TouchableOpacity style={styles.captureButton} onPress={takePicture}>
            <View style={styles.captureInner} />
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  // PREVIEW - Multi-Photo Gallery
  if (currentStep === 'preview' && capturedImages.length > 0) {
    return (
      <View style={styles.container}>
        <ScrollView 
          horizontal 
          pagingEnabled 
          showsHorizontalScrollIndicator={false}
          style={styles.previewScroll}
        >
          {capturedImages.map((uri, index) => (
            <Image 
              key={index}
              source={{ uri }} 
              style={styles.previewImage} 
              resizeMode="contain" 
            />
          ))}
        </ScrollView>
        
        <SafeAreaView style={styles.topBar}>
          <TouchableOpacity 
            style={styles.iconButton} 
            onPress={() => {
              setCapturedImages([]);
              setCurrentStep('camera');
            }}
          >
            <ChevronLeft size={28} color="#fff" />
          </TouchableOpacity>
        </SafeAreaView>

        <View style={styles.photoCounter}>
          <Text style={styles.photoCounterText}>
            {capturedImages.length} photo{capturedImages.length !== 1 ? 's' : ''}
          </Text>
        </View>

        <View style={styles.bottomBar}>
          <TouchableOpacity
            style={styles.confirmButton}
            onPress={() => setCurrentStep('details')}
          >
            <Check size={24} color="#fff" />
            <Text style={styles.confirmButtonText}>Use {capturedImages.length} Photo{capturedImages.length !== 1 ? 's' : ''}</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  // VEHICLE & PART DETAILS SCREEN
  if (currentStep === 'details' && capturedImages.length > 0) {
    return (
      <View style={styles.container}>
        <ScrollView 
          style={styles.detailsScroll}
          contentContainerStyle={styles.detailsContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Header */}
          <SafeAreaView style={styles.detailsHeader}>
            <TouchableOpacity 
              style={styles.iconButton}
              onPress={() => setCurrentStep('preview')}
            >
              <ChevronLeft size={28} color="#fff" />
            </TouchableOpacity>
            <Text style={styles.detailsTitle}>Add Car Details</Text>
            <View style={{ width: 48 }} />
          </SafeAreaView>

          {/* Photo Preview Carousel */}
          <ScrollView 
            horizontal 
            pagingEnabled 
            showsHorizontalScrollIndicator={false}
            style={styles.detailsPhotoScroll}
          >
            {capturedImages.map((uri, index) => (
              <Image 
                key={index}
                source={{ uri }} 
                style={styles.detailsPhotoPreview} 
                resizeMode="cover" 
              />
            ))}
          </ScrollView>

          {/* Car Make */}
          <Text style={styles.detailsLabel}>Car Make</Text>
          <TouchableOpacity 
            style={styles.detailsDropdown}
            onPress={() => setShowMakeModal(true)}
          >
            <Text style={[
              styles.detailsDropdownText,
              !selectedMake && styles.detailsDropdownPlaceholder
            ]}>
              {selectedMake || 'Select make (Toyota, VW, Ford...)'}
            </Text>
            <Car size={20} color="#888" />
          </TouchableOpacity>

          {/* Model & Year Row */}
          <View style={styles.detailsRow}>
            <View style={styles.detailsHalfInput}>
              <Text style={styles.detailsLabel}>Car Model</Text>
              <TouchableOpacity 
                style={styles.detailsDropdown}
                onPress={() => selectedMakeId ? setShowModelModal(true) : null}
                disabled={!selectedMakeId}
              >
                <Text style={[
                  styles.detailsDropdownText,
                  !selectedModel && styles.detailsDropdownPlaceholder,
                  !selectedMakeId && styles.detailsDropdownDisabled
                ]}>
                  {selectedMakeId ? (selectedModel || 'Model') : 'Select make first'}
                </Text>
              </TouchableOpacity>
            </View>

            <View style={styles.detailsHalfInput}>
              <Text style={styles.detailsLabel}>Year</Text>
              <TouchableOpacity 
                style={styles.detailsDropdown}
                onPress={() => setShowYearModal(true)}
              >
                <Text style={[
                  styles.detailsDropdownText,
                  !selectedYear && styles.detailsDropdownPlaceholder
                ]}>
                  {selectedYear || 'Year'}
                </Text>
                <Calendar size={20} color="#888" />
              </TouchableOpacity>
            </View>
          </View>

          {/* VIN Number */}
          <Text style={styles.detailsLabel}>VIN Number (Vehicle Identification Number)</Text>
          <View style={styles.detailsInputContainer}>
            <TextInput
              style={styles.detailsInput}
              placeholder="Enter VIN (e.g., 1HGBH41JXMN109186)"
              placeholderTextColor="#888"
              value={vinNumber}
              onChangeText={setVinNumber}
              autoCapitalize="characters"
              maxLength={17}
            />
            <Hash size={20} color="#888" />
          </View>

          {/* Engine Number */}
          <Text style={styles.detailsLabel}>Engine Number</Text>
          <View style={styles.detailsInputContainer}>
            <TextInput
              style={styles.detailsInput}
              placeholder="Enter engine number"
              placeholderTextColor="#888"
              value={engineNumber}
              onChangeText={setEngineNumber}
              autoCapitalize="characters"
            />
            <Hash size={20} color="#888" />
          </View>

          {/* Part Category Chips */}
          <Text style={styles.detailsLabel}>Part Category</Text>
          <View style={styles.detailsChipsContainer}>
            {['Engine', 'Suspension', 'Electrical', 'Body', 'Other'].map(category => (
              <TouchableOpacity
                key={category}
                style={[
                  styles.detailsChip,
                  selectedCategories.includes(category) && styles.detailsChipSelected,
                ]}
                onPress={() => toggleCategory(category)}
              >
                {selectedCategories.includes(category) && (
                  <Check size={16} color="#000" />
                )}
                <Text
                  style={[
                    styles.detailsChipText,
                    selectedCategories.includes(category) && styles.detailsChipTextSelected,
                  ]}
                >
                  {category}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Send Request Button */}
          <TouchableOpacity style={styles.sendRequestButton} onPress={submitRequest}>
            <Send size={24} color="#000" />
            <Text style={styles.sendRequestButtonText}>Send Request</Text>
          </TouchableOpacity>
        </ScrollView>

        {/* Dropdown Modals */}
        <DropdownModal
          visible={showMakeModal}
          onClose={() => setShowMakeModal(false)}
          title="Select Car Make"
          options={carMakes}
          selectedValue={selectedMake}
          onSelect={handleMakeSelect}
        />

        <DropdownModal
          visible={showModelModal}
          onClose={() => setShowModelModal(false)}
          title="Select Car Model"
          options={carModels}
          selectedValue={selectedModel}
          onSelect={setSelectedModel}
        />

        <DropdownModal
          visible={showYearModal}
          onClose={() => setShowYearModal(false)}
          title="Select Year"
          options={carYears.map(year => ({ id: year, name: year }))}
          selectedValue={selectedYear}
          onSelect={setSelectedYear}
        />
      </View>
    );
  }

  return null;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  topBar: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    zIndex: 10,
  },
  topRightControls: {
    flexDirection: 'row',
    gap: 12,
  },
  iconButton: {
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    padding: 12,
    borderRadius: 30,
  },
  rightControls: {
    position: 'absolute',
    right: 20,
    top: '40%',
    gap: 16,
    zIndex: 10,
  },
  gridOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    zIndex: 5,
  },
  gridLine: {
    position: 'absolute',
    backgroundColor: 'rgba(255, 255, 255, 0.3)',
    width: '100%',
    height: 1,
  },
  gridLineVertical: {
    width: 1,
    height: '100%',
  },
  bottomBar: {
    position: 'absolute',
    bottom: 40,
    left: 0,
    right: 0,
    alignItems: 'center',
    zIndex: 10,
  },
  captureButton: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: 'rgba(255, 255, 255, 0.3)',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  captureInner: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#fff',
  },
  message: {
    color: '#fff',
    fontSize: 18,
    textAlign: 'center',
    marginBottom: 20,
  },
  button: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 10,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  // Multi-photo mode styles
  thumbnailStrip: {
    position: 'absolute',
    bottom: 140,
    left: 0,
    right: 0,
    height: 100,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    paddingVertical: 10,
    paddingHorizontal: 10,
    zIndex: 10,
  },
  thumbnailScroll: {
    flex: 1,
  },
  thumbnailContainer: {
    marginRight: 10,
    position: 'relative',
  },
  thumbnail: {
    width: 70,
    height: 70,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#fff',
  },
  removeThumbnail: {
    position: 'absolute',
    top: -5,
    right: -5,
    backgroundColor: '#ff4444',
    borderRadius: 12,
    padding: 4,
  },
  photoCount: {
    color: '#fff',
    fontSize: 12,
    textAlign: 'center',
    marginTop: 5,
    fontWeight: '600',
  },
  doneButton: {
    position: 'absolute',
    left: 20,
    bottom: 0,
    backgroundColor: '#4CAF50',
    paddingHorizontal: 20,
    paddingVertical: 15,
    borderRadius: 40,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  doneButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
  // Preview screen styles
  previewScroll: {
    flex: 1,
  },
  previewImage: {
    width: width,
    height: '100%',
  },
  photoCounter: {
    position: 'absolute',
    top: 60,
    right: 20,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  photoCounterText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  confirmButton: {
    backgroundColor: '#4CAF50',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 40,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  confirmButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
  },
  // Vehicle & Part Details Screen styles
  detailsScroll: {
    flex: 1,
    backgroundColor: '#000',
  },
  detailsContent: {
    paddingBottom: 100,
  },
  detailsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 10,
    paddingBottom: 20,
  },
  detailsTitle: {
    fontSize: 22,
    fontWeight: '800',
    color: '#fff',
  },
  detailsPhotoScroll: {
    height: 300,
    marginBottom: 30,
  },
  detailsPhotoPreview: {
    width: width,
    height: 300,
  },
  detailsLabel: {
    color: '#aaa',
    fontSize: 14,
    marginBottom: 8,
    marginTop: 16,
    paddingHorizontal: 20,
    fontWeight: '500',
  },
  detailsDropdown: {
    backgroundColor: 'rgba(255,255,255,0.12)',
    padding: 16,
    marginHorizontal: 20,
    borderRadius: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
  },
  detailsDropdownText: {
    color: '#fff',
    fontSize: 17,
  },
  detailsDropdownPlaceholder: {
    color: '#888',
  },
  detailsDropdownDisabled: {
    color: '#555',
  },
  detailsInputContainer: {
    backgroundColor: 'rgba(255,255,255,0.12)',
    paddingHorizontal: 16,
    paddingVertical: 4,
    marginHorizontal: 20,
    borderRadius: 16,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
  },
  detailsInput: {
    flex: 1,
    color: '#fff',
    fontSize: 17,
    paddingVertical: 12,
  },
  detailsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    gap: 12,
  },
  detailsHalfInput: {
    flex: 1,
  },
  detailsChipsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 10,
    paddingHorizontal: 20,
  },
  detailsChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.1)',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 30,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
    gap: 6,
  },
  detailsChipSelected: {
    backgroundColor: '#fff',
    borderColor: '#fff',
  },
  detailsChipText: {
    color: '#ccc',
    fontSize: 15,
    fontWeight: '500',
  },
  detailsChipTextSelected: {
    color: '#000',
    fontWeight: '700',
  },
  sendRequestButton: {
    backgroundColor: '#fff',
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 18,
    borderRadius: 30,
    marginTop: 40,
    marginHorizontal: 20,
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  sendRequestButtonText: {
    color: '#000',
    fontSize: 18,
    fontWeight: '700',
  },
});
