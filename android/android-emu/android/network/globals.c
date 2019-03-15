// Copyright 2016 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "android/network/globals.h"

double android_net_upload_speed = 0.;
double android_net_download_speed = 0.;
int android_net_min_latency = 0;
int android_net_max_latency = 0;
int android_net_disable = 0;
int android_snapshot_update_timer = 1;
int is_qemu_2 = 0;