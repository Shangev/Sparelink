// App.tsx
import React, { useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ImageBackground,
  ScrollView,
  Image,
} from 'react-native';
import { ClipboardList, MessageCircle, Truck, Bell, Home, User } from 'lucide-react-native';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import RequestPartFlowExpo from './screens/RequestPartFlowMinimal';

const Stack = createStackNavigator();

// HomeScreen Component
function HomeScreen({ navigation }: any) {
  return (
    <View style={styles.container}>
      <StatusBar style="light" />
      {/* Full-bleed background - no status bar handling */}
      <ImageBackground
        source={{ uri: 'https://images.unsplash.com/photo-1581092580490-4a0e3be6f9b0?w=800' }}
        style={styles.background}
        blurRadius={12}
      >
        <ScrollView 
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Header */}
          <View style={styles.header}>
            <View style={styles.logoContainer}>
              <Image 
                source={require('./assets/images/home-logo.png')} 
                style={styles.logoImage}
                resizeMode="contain"
              />
            </View>
            <TouchableOpacity>
              <Bell size={24} color="#fff" />
            </TouchableOpacity>
          </View>

          {/* Hero Section */}
          <View style={styles.hero}>
            <Text style={styles.title}>Find any part.</Text>
            <Text style={styles.title}>Delivered fast.</Text>
            <Text style={styles.subtitle}>Snap a part → Get instant prices.</Text>
          </View>

          {/* 2×2 Grid */}
          <View style={styles.grid}>
            {/* Request a Part */}
            <TouchableOpacity 
              style={styles.card}
              onPress={() => navigation.navigate('RequestPartFlow')}
            >
              <Image 
                source={require('./assets/images/request-part-icon.png')} 
                style={styles.cardIconImage}
                resizeMode="contain"
              />
              <Text style={styles.cardTitle}>Request a Part</Text>
              <Text style={styles.cardSubtitle}>
                Upload photo & get instant prices from shops
              </Text>
            </TouchableOpacity>

            {/* My Requests */}
            <TouchableOpacity style={styles.card}>
              <ClipboardList size={28} color="#fff" />
              <Text style={styles.cardTitle}>My Requests</Text>
              <Text style={styles.cardSubtitle}>Track offers and deliveries</Text>
            </TouchableOpacity>

            {/* Chats with Shops */}
            <TouchableOpacity style={styles.card}>
              <MessageCircle size={28} color="#fff" />
              <Text style={styles.cardTitle}>Chats with Shops</Text>
              <Text style={styles.cardSubtitle}>Confirm part details before ordering</Text>
            </TouchableOpacity>

            {/* Deliveries */}
            <TouchableOpacity style={styles.card}>
              <Truck size={28} color="#fff" />
              <Text style={styles.cardTitle}>Deliveries</Text>
              <Text style={styles.cardSubtitle}>Track incoming part deliveries</Text>
            </TouchableOpacity>
          </View>
        </ScrollView>

        {/* Bottom Navigation */}
        <View style={styles.bottomNav}>
          <TouchableOpacity style={styles.navItemActive}>
            <Home size={24} color="#fff" />
            <Text style={styles.navLabelActive}>Home</Text>
          </TouchableOpacity>

          <TouchableOpacity 
            style={styles.navItem}
            onPress={() => navigation.navigate('RequestPartFlow')}
          >
            <Image 
              source={require('./assets/images/nav-request-icon.png')} 
              style={styles.navIconImage}
              resizeMode="contain"
            />
            <Text style={styles.navLabel}>My Requests</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.navItem}>
            <MessageCircle size={24} color="#888" />
            <Text style={styles.navLabel}>Chats</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.navItem}>
            <User size={24} color="#888" />
            <Text style={styles.navLabel}>Profile</Text>
          </TouchableOpacity>
        </View>
      </ImageBackground>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  background: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 50, // Manual top padding instead of SafeAreaView/StatusBar
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 100, // Space for bottom navigation
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  logoContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  logoImage: {
    width: 180,
    height: 40,
  },
  cardIconImage: {
    width: 28,
    height: 28,
  },
  navIconImage: {
    width: 24,
    height: 24,
    tintColor: '#888',
  },
  hero: {
    marginTop: 40,
    alignItems: 'center',
  },
  title: {
    fontSize: 36,
    fontWeight: '800',
    color: '#fff',
    textAlign: 'center',
    lineHeight: 42,
  },
  subtitle: {
    fontSize: 17,
    color: '#aaa',
    marginTop: 12,
    fontWeight: '500',
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginTop: 50,
  },
  card: {
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderRadius: 20,
    padding: 20,
    width: '47%',
    height: 160,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    marginBottom: 16,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#fff',
    textAlign: 'center',
    marginBottom: 6,
  },
  cardSubtitle: {
    fontSize: 13,
    color: '#ccc',
    textAlign: 'center',
    lineHeight: 18,
  },
  bottomNav: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    backgroundColor: 'rgba(0,0,0,0.7)',
    paddingVertical: 16,
    paddingHorizontal: 20,
    paddingBottom: 34, // Extra space for iPhone home indicator
    justifyContent: 'space-around',
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.1)',
  },
  navItem: {
    alignItems: 'center',
    gap: 4,
  },
  navItemActive: {
    alignItems: 'center',
    gap: 4,
  },
  navLabel: {
    fontSize: 11,
    color: '#888',
  },
  navLabelActive: {
    fontSize: 11,
    color: '#fff',
    fontWeight: '600',
  },
});

// Main App Component with Navigation
export default function App() {
  const [currentScreen, setCurrentScreen] = React.useState('Home');

  if (currentScreen === 'RequestPartFlow') {
    return <RequestPartFlowExpo navigation={{ goBack: () => setCurrentScreen('Home') }} />;
  }

  return <HomeScreen navigation={{ navigate: (screen: string) => setCurrentScreen(screen) }} />;
}
