from datetime import datetime
from datetime import timezone


class avg_bucket:    
    def __init__(self, name):
        self.name = str(name)
        self.avg = 0
        self.points = 0
        self.mtime = 0
        
    def __str__(self):
        
        return self.name + ": avg:" + str(self.avg) + ", points:" + str(self.points) + ', updated on:' + str(self.mtime)
    
    def add_point(self, measurement):
        self.avg = (self.avg * self.points + measurement) / (self.points + 1)
        self.points = self.points + 1
        self.mtime = int(datetime.now().replace(tzinfo=timezone.utc).timestamp())
        
class avg_buckets:    
    
    def __init__(self, measurement_metric_name, slot_size_timestamp):
        self.name = str(measurement_metric_name)
        self.slot_size_timestamp = slot_size_timestamp
        
        self.avg_slots= dict()
        
    def __str__(self):
        return "metric name: " + self.name + ", slot: " + str(self.slot_size_timestamp)
    
    def get_bucket_timestamp(self, measurement_date_time):
        measurement_timestamp = int(measurement_date_time.replace(tzinfo=timezone.utc).timestamp())
        measurement_timestamp_bucket = measurement_timestamp - measurement_timestamp % self.slot_size_timestamp
        
        return measurement_timestamp_bucket
    
    def get_bucket_timestamp_str(self, measurement_date_time_str):
        measurement_date_time = datetime.strptime(measurement_date_time_str, '%Y-%m-%d %H:%M:%S %Z')
        
        return self.get_bucket_timestamp(measurement_date_time)
    
    def add_point(self, measurement_date_time_str, measurement_value):
        
        measurement_timestamp_bucket = self.get_bucket_timestamp_str(measurement_date_time_str)
        
        if measurement_timestamp_bucket in self.avg_slots:
            bucket = self.avg_slots[measurement_timestamp_bucket]
        else:
            self.avg_slots[measurement_timestamp_bucket] = avg_bucket(measurement_timestamp_bucket)
            bucket = self.avg_slots[measurement_timestamp_bucket]
            
        bucket.add_point(measurement_value)
    
    def dump(self):
        print(self)
        print("{:<20} {:<30} {:<15} {:<20} {:<30}".format('bucket', 'time', 'points','avg', 'updated'))
        for k, v in self.avg_slots.items():
            time = datetime.utcfromtimestamp(k).strftime('%Y-%m-%d %H:%M:%S')
            points = v.points
            avg = v.avg
            mtime = v.mtime
            print("{:<20} {:<30} {:<15} {:<20} {:<30}".format(k, time, points, avg, mtime))
            

class c_score():
    
    def __init__(self, measurement_metric_name, short_slot_size_timestamp, long_slot_size_timestamp):
        self.name = str(measurement_metric_name)
        self.long_slot = avg_buckets(measurement_metric_name + "_long", long_slot_size_timestamp)
        self.short_slot = avg_buckets(measurement_metric_name + "_short", short_slot_size_timestamp)

    def add_point(self, measurement_date_time_str, measurement_value):
        self.long_slot.add_point(measurement_date_time_str, measurement_value)
        self.short_slot.add_point(measurement_date_time_str, measurement_value)
        
    def get_score(self, score_datetime):
        short_bucket = self.short_slot.get_bucket_timestamp(score_datetime)
        long_bucket = self.long_slot.get_bucket_timestamp(score_datetime)
    
        c_score = (self.short_slot.avg_slots[short_bucket].avg / self.long_slot.avg_slots[long_bucket].avg) - 1
        
        print('DEBUG: short_bucket:' + self.short_slot.avg_slots[short_bucket].__str__())
        print('DEBUG: long_bucket:' + self.long_slot.avg_slots[long_bucket].__str__())
        
        return c_score
    
    def dump(self):
        self.short_slot.dump()
        self.long_slot.dump()
        
