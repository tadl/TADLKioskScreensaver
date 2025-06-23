# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
%w[admin manage_kiosks manage_kioskgroups manage_slides manage_users].each do |perm|
  Permission.find_or_create_by!(name: perm) do |p|
    p.description = case perm
    when 'admin'             then 'Full access to everything'
    when 'manage_kiosks'     then 'Can create/edit/delete kiosks'
    when 'manage_kioskgroups' then 'Can create/edit/delete kiosk groups'
    when 'manage_slides'     then 'Can upload and manage slides'
    when 'manage_users'      then 'Can invite, edit and remove users'
    end
  end
end

