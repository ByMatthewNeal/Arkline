import { redirect } from 'next/navigation';

// Renamed to Broadcasts. Keep this route as a permanent redirect for old links.
export default function CommunityRedirect() {
  redirect('/dashboard/broadcasts');
}
