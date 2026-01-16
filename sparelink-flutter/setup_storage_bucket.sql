-- =============================================
-- SETUP STORAGE BUCKET FOR PART IMAGES
-- Run this in Supabase SQL Editor
-- =============================================

-- Create the storage bucket for part images
INSERT INTO storage.buckets (id, name, public)
VALUES ('part-images', 'part-images', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload images
CREATE POLICY "Authenticated users can upload part images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'part-images');

-- Allow public read access to part images
CREATE POLICY "Public read access for part images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'part-images');

-- Allow users to delete their own images (optional)
CREATE POLICY "Users can delete own part images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'part-images' AND auth.uid()::text = (storage.foldername(name))[1]);
