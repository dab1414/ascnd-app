import { StatusBar } from 'expo-status-bar';
import { StyleSheet, Text, View } from 'react-native';
import { SQLiteProvider } from 'expo-sqlite';
import { migrateDbIfNeeded } from './db/driver';

export default function App() {
  return (
    <SQLiteProvider databaseName="arc.db" onInit={migrateDbIfNeeded}>
      <View style={styles.container}>
        <Text>ASCND APP TEST</Text>
      </View>
    </SQLiteProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
