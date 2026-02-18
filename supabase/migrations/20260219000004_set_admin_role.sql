-- Set admin role for the app creator's profile
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'mneal.jw@gmail.com';
