import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Image,
  ActivityIndicator,
  SafeAreaView,
  ScrollView,
} from 'react-native';
import { Camera, Bell, MessageCircle, Home, ClipboardList, User } from 'lucide-react-native';

type ChatItem = {
  id: string;
  shop_id: string;
  shop_name: string;
  shop_avatar_url: string;
  shop_address: string;
  last_message: string;
  last_message_time: string;
  image_urls: string[];
  unread_count: number;
};

const API_URL = 'http://localhost:3333/api';

export default function ChatsScreen({ navigation, route }: any) {
  const [chats, setChats] = useState<ChatItem[]>([]);
  const [loading, setLoading] = useState(true);
  
  const userId = route?.params?.userId || 'test-user-id';

  useEffect(() => {
    loadChats();
  }, []);

  const loadChats = async () => {
    try {
      setLoading(true);
      const response = await fetch(`${API_URL}/conversations/${userId}`);
      const data = await response.json();
      setChats(data);
    } catch (error) {
      console.error('Failed to load chats:', error);
      setChats([]); // Set empty array on error
    } finally {
      setLoading(false);
    }
  };

  const formatTimestamp = (timestamp: string) => {
    if (!timestamp) return 'Just now';
    
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  const renderChatItem = ({ item }: { item: ChatItem }) => {
    const hasMultipleImages = item.image_urls && item.image_urls.length > 1;
    const firstImage = item.image_urls && item.image_urls.length > 0 ? item.image_urls[0] : null;
    
    return (
      <TouchableOpacity
        style={styles.chatItem}
        onPress={() => {
          // Navigate to chat detail (not implemented yet)
          console.log('Open chat with shop:', item.shop_name);
        }}
      >
        {/* Shop Avatar */}
        <View style={styles.avatarContainer}>
          {item.shop_avatar_url ? (
            <Image 
              source={{ uri: item.shop_avatar_url }} 
              style={styles.avatar}
            />
          ) : (
            <View style={styles.avatar}>
              <Text style={styles.avatarText}>
                {(item.shop_name || 'S').charAt(0).toUpperCase()}
              </Text>
            </View>
          )}
        </View>

        {/* Chat Content */}
        <View style={styles.chatContent}>
          <View style={styles.headerRow}>
            <Text style={styles.shopName} numberOfLines={1}>
              {item.shop_name || 'Shop'}
            </Text>
            <Text style={styles.timestamp}>
              {formatTimestamp(item.last_message_time)}
            </Text>
          </View>
          
          <Text style={styles.location} numberOfLines={1}>
            {item.shop_address || 'Location'}
          </Text>
          
          <View style={styles.messageRow}>
            <Text style={styles.message} numberOfLines={1}>
              {item.last_message || 'I sent a part request'}
            </Text>
            {item.unread_count > 0 && (
              <View style={styles.unreadBadge}>
                <Text style={styles.unreadText}>{item.unread_count}</Text>
              </View>
            )}
          </View>
        </View>

        {/* Part Image Preview */}
        <View style={styles.partImageContainer}>
          {firstImage ? (
            <View>
              <Image 
                source={{ uri: firstImage }} 
                style={styles.partImage}
              />
              {hasMultipleImages && (
                <View style={styles.multipleImagesIndicator}>
                  <Text style={styles.multipleImagesText}>+{item.image_urls.length - 1}</Text>
                </View>
              )}
            </View>
          ) : (
            <View style={styles.partImagePlaceholder}>
              <Text style={styles.partImageIcon}>🔧</Text>
            </View>
          )}
        </View>
      </TouchableOpacity>
    );
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <SafeAreaView style={styles.headerSafeArea}>
          <View style={styles.header}>
            <View style={styles.logo}>
              <Camera size={32} color="#fff" />
              <Text style={styles.logoText}>SpareLink</Text>
            </View>
            <TouchableOpacity>
              <Bell size={28} color="#fff" />
            </TouchableOpacity>
          </View>
        </SafeAreaView>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#4CAF50" />
          <Text style={styles.loadingText}>Loading chats...</Text>
        </View>
        <View style={styles.bottomNav}>
          <TouchableOpacity style={styles.navItem} onPress={() => navigation.navigate('Home')}>
            <Home size={24} color="#666" />
            <Text style={styles.navLabel}>Home</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.navItem}>
            <ClipboardList size={24} color="#666" />
            <Text style={styles.navLabel}>Requests</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.navItemActive}>
            <MessageCircle size={28} color="#4CAF50" />
            <Text style={styles.navLabelActive}>Chats</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.navItem}>
            <User size={24} color="#666" />
            <Text style={styles.navLabel}>Profile</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <SafeAreaView style={styles.headerSafeArea}>
        <View style={styles.header}>
          <View style={styles.logo}>
            <Camera size={32} color="#fff" />
            <Text style={styles.logoText}>SpareLink</Text>
          </View>
          <TouchableOpacity>
            <Bell size={28} color="#fff" />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      {/* Chats List */}
      {chats.length === 0 ? (
        <View style={styles.emptyContainer}>
          <MessageCircle size={64} color="#444" />
          <Text style={styles.emptyTitle}>No chats yet</Text>
          <Text style={styles.emptySubtitle}>
            Send a part request to start chatting with shops
          </Text>
          <TouchableOpacity 
            style={styles.emptyButton}
            onPress={() => navigation.navigate('RequestPartFlow')}
          >
            <Text style={styles.emptyButtonText}>Request a Part</Text>
          </TouchableOpacity>
        </View>
      ) : (
        <FlatList
          data={chats}
          keyExtractor={(item) => item.id}
          renderItem={renderChatItem}
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.listContent}
        />
      )}

      {/* Bottom Navigation */}
      <View style={styles.bottomNav}>
        <TouchableOpacity style={styles.navItem} onPress={() => navigation.navigate('Home')}>
          <Home size={24} color="#666" />
          <Text style={styles.navLabel}>Home</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.navItem}>
          <ClipboardList size={24} color="#666" />
          <Text style={styles.navLabel}>Requests</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.navItemActive}>
          <MessageCircle size={28} color="#4CAF50" />
          <Text style={styles.navLabelActive}>Chats</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.navItem}>
          <User size={24} color="#666" />
          <Text style={styles.navLabel}>Profile</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { 
    flex: 1, 
    backgroundColor: '#000' 
  },
  headerSafeArea: {
    backgroundColor: '#000',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 12,
    paddingBottom: 16,
    backgroundColor: '#000',
  },
  logo: { 
    flexDirection: 'row', 
    alignItems: 'center', 
    gap: 10 
  },
  logoText: { 
    fontSize: 26, 
    fontWeight: '800', 
    color: '#fff' 
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    color: '#888',
    fontSize: 16,
    marginTop: 12,
  },
  listContent: {
    paddingBottom: 100,
  },
  chatItem: {
    flexDirection: 'row',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#1a1a1a',
    alignItems: 'center',
  },
  avatarContainer: { 
    marginRight: 12 
  },
  avatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#2a2a2a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    fontSize: 24,
    fontWeight: '700',
    color: '#4CAF50',
  },
  chatContent: { 
    flex: 1,
    marginRight: 12,
  },
  headerRow: { 
    flexDirection: 'row', 
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  shopName: { 
    color: '#fff', 
    fontSize: 17, 
    fontWeight: '700',
    flex: 1,
    marginRight: 8,
  },
  timestamp: { 
    color: '#888', 
    fontSize: 13 
  },
  location: { 
    color: '#888', 
    fontSize: 14, 
    marginBottom: 4 
  },
  messageRow: { 
    flexDirection: 'row', 
    alignItems: 'center',
    gap: 8 
  },
  message: { 
    color: '#aaa', 
    fontSize: 15,
    flex: 1,
  },
  unreadBadge: {
    backgroundColor: '#f33',
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 6,
  },
  unreadText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '700',
  },
  partImageContainer: { 
    alignItems: 'center',
    justifyContent: 'center',
  },
  partImage: {
    width: 60,
    height: 60,
    borderRadius: 12,
    backgroundColor: '#1a1a1a',
  },
  partImagePlaceholder: {
    width: 60,
    height: 60,
    borderRadius: 12,
    backgroundColor: '#1a1a1a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  partImageIcon: { 
    fontSize: 28,
  },
  multipleImagesIndicator: {
    position: 'absolute',
    bottom: 4,
    right: 4,
    backgroundColor: 'rgba(0, 0, 0, 0.8)',
    borderRadius: 8,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  multipleImagesText: {
    color: '#fff',
    fontSize: 10,
    fontWeight: '700',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 40,
  },
  emptyTitle: {
    color: '#fff',
    fontSize: 24,
    fontWeight: '700',
    marginTop: 20,
    marginBottom: 8,
  },
  emptySubtitle: {
    color: '#888',
    fontSize: 16,
    textAlign: 'center',
    marginBottom: 24,
  },
  emptyButton: {
    backgroundColor: '#4CAF50',
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 12,
  },
  emptyButtonText: {
    color: '#000',
    fontSize: 16,
    fontWeight: '700',
  },
  bottomNav: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    backgroundColor: '#0a0a0a',
    paddingVertical: 12,
    paddingBottom: 34,
    justifyContent: 'space-around',
    borderTopWidth: 1,
    borderTopColor: '#1a1a1a',
  },
  navItem: { 
    alignItems: 'center', 
    gap: 4 
  },
  navItemActive: { 
    alignItems: 'center', 
    gap: 4 
  },
  navLabel: {
    color: '#666',
    fontSize: 12,
    fontWeight: '500',
  },
  navLabelActive: { 
    color: '#4CAF50', 
    fontSize: 12, 
    fontWeight: '700' 
  },
});
