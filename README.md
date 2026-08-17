# TADL Kiosk Screensaver
<table><tr>
  <td valign="top">
    A Rails application to manage and serve full‑screen slideshows on library kiosks. Allows uploading 1920×1080 images, scheduling display durations, and assigning slides to individual kiosks via an admin interface.
  </td><td valign="top" width="200">
    <img src="https://raw.githubusercontent.com/tadl/TADLKioskScreensaver/main/app/assets/images/mascot-kio.png" alt="Kiosk Screensaver Mascot" width="200" />
  </td>
</tr></table>

## Key Features

* **Slide Management**: Upload 1920×1080 images, set display duration, optional start/end dates.
* **Kiosk Assignment**: Assign slides to one or more kiosks.
* **User Permissions**: Granular access control with CanCanCan and user/group permissions.
* **Admin UI**: Full CRUD admin interface powered by RailsAdmin.
* **Image Storage**: ActiveStorage for uploads; local disk in development, mounted storage in production.

## Technology Stack

* Ruby 3.4.10, Rails 8.1
* PostgreSQL
* RailsAdmin 3.3.0
* CanCanCan
* ActiveStorage
* Importmap & Hotwire (Turbo)
* dotenv (development)
* Dokku / Heroku deployment

## Getting Started

### Prerequisites

* Ruby 3.4.10
* PostgreSQL
* Bundler 2.6.9

### Setup (Development)

1. **Clone repository**

   ```bash
   git clone https://github.com/tadl/TADLKioskScreensaver.git
   cd TADLKioskScreensaver
   ```

2. **Install gems**

   ```bash
   bundle install
   ```

3. **Environment variables**

   * Copy `.env.example` to `.env` and configure Google OAuth, `KIOSK_API_PSK`, `LOCATION_DATA_URL`, and any database overrides.
   * Uses [dotenv](https://github.com/bkeepers/dotenv) to load `.env` in development.

4. **Database setup**

   ```bash
   bin/rails db:prepare
   ```

5. **Start server**

   ```bash
   bin/dev
   ```

6. **Access admin**
   Navigate to `http://localhost:3000/admin` and sign in via configured OAuth.

## Configuration

### Development

* Environment variables live in `.env` (loaded via dotenv).
* ActiveStorage uses local disk (in `storage/`).
* Kiosk heartbeat and log clients authenticate with the `X-Kiosk-Key` header using `KIOSK_API_PSK`.

### Initial administrator

After the administrator has signed in once with Google, bootstrap the account from a Rails console or runner:

```bash
bin/rails runner 'User.find_by!(email: "you@example.com").update!(admin: true)'
```

Production deployments must mount `storage/` persistently so uploaded slides survive container replacement.

## Contributing

1. Fork the repo
2. Create a feature branch
3. Submit a pull request

---

*This application powers digital signage for library kiosks. Adjust configurations as needed per environment.*
