# IMDB Sample Database - Docker Setup

This Docker Compose setup creates a MySQL database with the IMDB sample database schema and data automatically loaded.

The IMDb database models the entertainment industry with comprehensive information about movies, TV shows, and the talent behind them. It covers titles across different content types and genres, cast and crew assignments with their specific roles, alternative regional titles and languages, episode structures for TV series, and production regions. The data supports film research, recommendation systems, and entertainment analytics.

## Files

- `docker-compose.yml` - Docker Compose configuration
- `imdb-schema.sql` - Database schema adapted from [1]
- `csv-data/` - Directory containing CSV data files for all tables [1]
- `model.png' - Entity-Relationship Diagram of the IMDB database [2]

This database uses sampled data from the IMDB non-commercial datasets.
Data files are located in the `csv-data/` directory.

## Usage

### Start the database

```bash
docker-compose up -d
```
### Access phpMyAdmin (Web Interface)

Open your browser and go to:
```
http://localhost:8080
```

**Login credentials:**
- Username: `northwind_user`
- Password: `northwind_pass`

**Or login as root:**
- Username: `root`
- Password: `root`


### Connect via command line

**Connection Details:**
- Host: `localhost`
- Port: `3306`
- Database: `imdb`
- Username: `imdb_user`
- Password: `imdb_pass`
- Root password: `root`

**Using MySQL command line:**
```bash
docker exec -it imdb-mysql mysql -u imdb_user -pimdb_pass imdb
```


### Stop the database

```bash
docker compose down
```

### Stop and remove all data

```bash
docker compose down -v
```


1. Access the database:
   - **MySQL Connection:**
     - Host: `localhost`
     - Port: `3306`
     - Database: `imdb`
     - Username: `imdb_user`
     - Password: `imdb_pass`
     - Root Password: `root`

   - **phpMyAdmin:** 
     - URL: http://localhost:8080
     - Username: `imdb_user`
     - Password: `imdb_pass`

## Management Commands

### Start the containers
```bash
docker-compose up -d
```

### Stop the containers
```bash
docker-compose down
```

### Stop and remove all data (fresh start)
```bash
docker-compose down -v
```

## References

[1] northcoder-repo. "Sample IMDb data for relational databases. For testing/demo purposes only." GitHub repository. https://github.com/northcoder-repo/relational-sample-IMDB-data
[2] northcoder. "Using IMDb as a Test Data Set". 11 Nov 2019. Blog post. https://northcoder.com/blog/using-imdb-as-a-test-data-set