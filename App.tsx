import React, { useEffect, useState } from 'react';
import { Text, View, ScrollView, StyleSheet } from 'react-native';
import { SQLiteProvider, useSQLiteContext } from 'expo-sqlite';
import { migrateDbIfNeeded } from './db/driver';
import { StatusBar } from 'expo-status-bar';


type ExerciseRow = {
  id: string;
  name: string;
  training_type: 'mobility' | 'cardio' | 'resistance' | 'skill';
};

function ExerciseList() {
  const db = useSQLiteContext();
  const [exercises, setExercises] = useState<ExerciseRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const rows = await db.getAllAsync<ExerciseRow>(
          'SELECT id, name, training_type FROM exercise WHERE is_active = 1 ORDER BY name'
        );
        setExercises(rows);
      } catch (e) {
        console.error('Error loading exercises', e);
      } finally {
        setLoading(false);
      }
    })();
  }, [db]);

  if (loading) {
    return <Text>Loading exercises...</Text>;
  }

  if (exercises.length === 0) {
    return <Text>No exercises found.</Text>;
  }

  return (
    <ScrollView style={{ marginTop: 16 }}>
      {exercises.map((ex) => (
        <Text key={ex.id} style={{ marginBottom: 4 }}>
          {ex.name} ({ex.training_type})
        </Text>
      ))}
    </ScrollView>
  );
}

export default function App() {
  return (
    <SQLiteProvider databaseName="arc.db" onInit={migrateDbIfNeeded}>
      <View style={styles.container}>
        <Text style={styles.title}>ASCND APP</Text>
        <ExerciseList />
      </View>
    </SQLiteProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 48,
    paddingHorizontal: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: '600',
  },
});

